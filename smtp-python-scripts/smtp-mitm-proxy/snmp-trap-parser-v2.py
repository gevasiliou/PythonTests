#!/usr/bin/env python3
"""
snmp_parser.py  —  Pure Python SNMP Trap Parser + Listener
Supports: SNMPv1 Trap (0xA4), SNMPv2c Inform (0xA6), SNMPv2c Trap (0xA7)
No third-party libraries. Standard library only.

Can run as:
  1. Standalone listener : sudo python snmp_parser.py --port 162
  2. Test against captured bytes : python snmp_parser.py --test
  3. Importable module   : from snmp_parser import parse_trap

ComAp trap format mapping:
  v1 Trap      → SNMPv1 Trap PDU   (0xA4)  fire-and-forget, different structure
  v2 Notific   → SNMPv2c Trap PDU  (0xA7)  fire-and-forget  ← recommended
  v2 Inform    → SNMPv2c Inform    (0xA6)  requires ACK from receiver
"""

import socket
import argparse
import datetime
import sys

# ─────────────────────────────────────────────────────────────────
#  BER Tag Constants  (RFC 3416)
# ─────────────────────────────────────────────────────────────────

TAG_INTEGER      = 0x02
TAG_OCTET_STRING = 0x04
TAG_NULL         = 0x05
TAG_OID          = 0x06
TAG_SEQUENCE     = 0x30
TAG_IPADDRESS    = 0x40
TAG_COUNTER32    = 0x41
TAG_GAUGE32      = 0x42
TAG_TIMETICKS    = 0x43
TAG_COUNTER64    = 0x46
TAG_PDU_V1_TRAP  = 0xA4   # SNMPv1 Trap-PDU       — completely different structure
TAG_PDU_INFORM   = 0xA6   # SNMPv2c InformRequest — requires ACK (v2 Inform in ComAp)
TAG_PDU_V2_TRAP  = 0xA7   # SNMPv2c Trap-PDU      — fire and forget (v2 Notific in ComAp)

TAG_NAMES = {
    TAG_INTEGER:      "INTEGER",
    TAG_OCTET_STRING: "OCTET_STRING",
    TAG_NULL:         "NULL",
    TAG_OID:          "OID",
    TAG_SEQUENCE:     "SEQUENCE",
    TAG_IPADDRESS:    "IpAddress",
    TAG_COUNTER32:    "Counter32",
    TAG_GAUGE32:      "Gauge32",
    TAG_TIMETICKS:    "TimeTicks",
    TAG_COUNTER64:    "Counter64",
    TAG_PDU_V1_TRAP:  "SNMPv1-Trap-PDU",
    TAG_PDU_INFORM:   "SNMPv2c-InformRequest  (ACK required)",
    TAG_PDU_V2_TRAP:  "SNMPv2c-Trap-PDU",
}

# SNMPv1 generic trap type names
V1_GENERIC_TRAP = {
    0: "coldStart",
    1: "warmStart",
    2: "linkDown",
    3: "linkUp",
    4: "authenticationFailure",
    5: "egpNeighborLoss",
    6: "enterpriseSpecific",
}

# ─────────────────────────────────────────────────────────────────
#  Optional OID name lookup — extend as needed
#  Run with --test first to discover your actual enterprise OIDs
# ─────────────────────────────────────────────────────────────────

OID_NAMES = {
    "1.3.6.1.2.1.1.3.0":           "sysUpTime",
    "1.3.6.1.6.3.1.1.4.1.0":       "snmpTrapOID",
    # ComAp enterprise OID: 1.3.6.1.4.1.28634
    "1.3.6.1.4.1.28634.29.6.1.0":  "comap.model",
    "1.3.6.1.4.1.28634.29.6.2.0":  "comap.serial",
    "1.3.6.1.4.1.28634.29.6.3.0":  "comap.alarm",
}


# ─────────────────────────────────────────────────────────────────
#  BER Primitives
# ─────────────────────────────────────────────────────────────────

def decode_length(data: bytes, offset: int) -> tuple:
    """
    Decode a BER length field starting at offset.
    Returns (length_value, new_offset).

    Short form : single byte, value 0-127
    Long form  : first byte = 0x80 | n  where n = how many bytes follow
                 those n bytes encode the actual length (big-endian)
    """
    first = data[offset]
    offset += 1

    if first & 0x80 == 0:
        # Short form — the byte itself is the length
        return first, offset
    else:
        # Long form — low 7 bits tell us how many bytes encode the length
        n_bytes = first & 0x7F
        length = 0
        for _ in range(n_bytes):
            length = (length << 8) | data[offset]
            offset += 1
        return length, offset


def read_tlv(data: bytes, offset: int) -> tuple:
    """
    Read one TLV (Type-Length-Value) at offset.
    Returns (tag, value_offset, value_length, next_offset).

    next_offset points to the byte immediately after this TLV's value.
    """
    tag          = data[offset]
    offset      += 1
    length, offset = decode_length(data, offset)
    value_offset = offset
    next_offset  = offset + length
    return tag, value_offset, length, next_offset


def decode_integer(data: bytes, offset: int, length: int) -> int:
    """Decode a BER INTEGER (big-endian, signed two's complement)."""
    value = 0
    for i in range(length):
        value = (value << 8) | data[offset + i]
    # If high bit of first byte is set, the integer is negative
    if length > 0 and (data[offset] & 0x80):
        value -= (1 << (8 * length))
    return value


def decode_unsigned(data: bytes, offset: int, length: int) -> int:
    """Decode an unsigned integer (Counter32, Gauge32, TimeTicks)."""
    value = 0
    for i in range(length):
        value = (value << 8) | data[offset + i]
    return value


def decode_octet_string(data: bytes, offset: int, length: int) -> str:
    """
    Decode a BER OCTET STRING.
    Tries UTF-8 first. Falls back to colon-separated hex if not printable.
    """
    raw = data[offset : offset + length]
    try:
        text = raw.decode("utf-8")
        # Only return as string if all chars are printable
        if all(c.isprintable() or c in ('\n', '\r', '\t') for c in text):
            return text
        raise ValueError("non-printable")
    except (UnicodeDecodeError, ValueError):
        return "0x" + raw.hex().upper()


def decode_oid(data: bytes, offset: int, length: int) -> str:
    """
    Decode a BER OID.

    First byte encodes two components:
        first  = byte // 40   (always 0, 1 or 2)
        second = byte % 40

    Remaining subidentifiers use base-128 encoding:
        - Each subidentifier may span multiple bytes
        - High bit (0x80) set  → more bytes follow for this subidentifier
        - High bit (0x80) clear → last byte of this subidentifier
        - Each byte contributes its low 7 bits
    """
    if length == 0:
        return ""

    parts = []
    end   = offset + length

    # First byte — two components packed together
    first_byte = data[offset]
    parts.append(first_byte // 40)
    parts.append(first_byte % 40)
    offset += 1

    # Remaining subidentifiers
    while offset < end:
        value = 0
        while True:
            byte   = data[offset]
            offset += 1
            value  = (value << 7) | (byte & 0x7F)
            if not (byte & 0x80):   # High bit clear = last byte of subidentifier
                break
        parts.append(value)

    return ".".join(str(p) for p in parts)


def decode_ipaddress(data: bytes, offset: int, length: int) -> str:
    """Decode a 4-byte SNMP IpAddress."""
    if length != 4:
        return f"invalid-ip ({length} bytes)"
    return ".".join(str(data[offset + i]) for i in range(4))


def decode_value(tag: int, data: bytes, value_offset: int, value_length: int) -> str:
    """Dispatch to the correct decoder based on the BER tag byte."""
    if tag == TAG_INTEGER:
        return str(decode_integer(data, value_offset, value_length))

    elif tag == TAG_OCTET_STRING:
        return decode_octet_string(data, value_offset, value_length)

    elif tag == TAG_OID:
        oid   = decode_oid(data, value_offset, value_length)
        label = OID_NAMES.get(oid, "")
        return f"{oid}  ({label})" if label else oid

    elif tag == TAG_TIMETICKS:
        ticks   = decode_unsigned(data, value_offset, value_length)
        seconds = ticks // 100
        h, rem  = divmod(seconds, 3600)
        m, s    = divmod(rem, 60)
        return f"{ticks} ticks  ({h:02d}h {m:02d}m {s:02d}s uptime)"

    elif tag in (TAG_COUNTER32, TAG_GAUGE32):
        return str(decode_unsigned(data, value_offset, value_length))

    elif tag == TAG_COUNTER64:
        return str(decode_unsigned(data, value_offset, value_length))

    elif tag == TAG_IPADDRESS:
        return decode_ipaddress(data, value_offset, value_length)

    elif tag == TAG_NULL:
        return "NULL"

    else:
        raw = data[value_offset : value_offset + value_length]
        return f"0x{raw.hex().upper()}  (unknown tag 0x{tag:02X})"


# ─────────────────────────────────────────────────────────────────
#  SNMP-Specific Decoders
# ─────────────────────────────────────────────────────────────────

def parse_varbinds(data: bytes, offset: int, end: int) -> list:
    """
    Parse the varbind list SEQUENCE.

    A varbind list is a SEQUENCE of varbinds.
    Each varbind is itself a SEQUENCE containing exactly two items:
        1. An OID  — identifies what is being reported
        2. A value — the actual data (any BER type)

    Returns a list of dicts: {oid, oid_name, value_type, value}
    """
    varbinds = []

    while offset < end:
        # Each varbind is wrapped in a SEQUENCE
        tag, vb_offset, vb_length, next_vb = read_tlv(data, offset)

        if tag != TAG_SEQUENCE:
            break   # Unexpected tag — stop safely

        vb_end = vb_offset + vb_length

        # Read the OID
        oid_tag, oid_offset, oid_length, after_oid = read_tlv(data, vb_offset)
        oid_str  = decode_oid(data, oid_offset, oid_length)
        oid_name = OID_NAMES.get(oid_str, "")

        # Read the value
        val_tag, val_offset, val_length, _ = read_tlv(data, after_oid)
        value_str = decode_value(val_tag, data, val_offset, val_length)

        varbinds.append({
            "oid":        oid_str,
            "oid_name":   oid_name,
            "value_type": TAG_NAMES.get(val_tag, f"0x{val_tag:02X}"),
            "value":      value_str,
        })

        offset = next_vb

    return varbinds


def parse_v1_trap_pdu(data: bytes, offset: int, result: dict) -> None:
    """
    Parse SNMPv1 Trap-PDU (0xA4) body.

    SNMPv1 PDU structure is completely different from v2c:
        OID        enterprise       — which MIB object generated the trap
        IpAddress  agent-addr       — IP of the sending device
        INTEGER    generic-trap     — 0=coldStart … 6=enterpriseSpecific
        INTEGER    specific-trap    — vendor-defined code when generic=6
        TimeTicks  time-stamp       — sysUpTime when trap was generated
        SEQUENCE   varbind-list     — additional data
    """
    # Enterprise OID
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    result["enterprise"] = decode_oid(data, val_offset, val_length)

    # Agent address
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    result["agent_addr"] = decode_ipaddress(data, val_offset, val_length)

    # Generic trap type
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    generic = decode_integer(data, val_offset, val_length)
    result["generic_trap"] = f"{generic} ({V1_GENERIC_TRAP.get(generic, 'unknown')})"

    # Specific trap type
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    result["specific_trap"] = decode_integer(data, val_offset, val_length)

    # Timestamp
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    ticks   = decode_unsigned(data, val_offset, val_length)
    seconds = ticks // 100
    h, rem  = divmod(seconds, 3600)
    m, s    = divmod(rem, 60)
    result["timestamp_ticks"] = f"{ticks} ticks  ({h:02d}h {m:02d}m {s:02d}s)"

    # Varbind list
    tag, vbl_offset, vbl_length, _ = read_tlv(data, offset)
    result["varbinds"] = parse_varbinds(data, vbl_offset, vbl_offset + vbl_length)


def parse_v2_pdu(data: bytes, offset: int, result: dict) -> None:
    """
    Parse SNMPv2c Trap-PDU (0xA7) or InformRequest-PDU (0xA6) body.

    Both share the same structure:
        INTEGER    request-id
        INTEGER    error-status   (always 0 in traps)
        INTEGER    error-index    (always 0 in traps)
        SEQUENCE   varbind-list
    """
    # Request ID
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    result["request_id"] = decode_integer(data, val_offset, val_length)

    # Error Status
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    result["error_status"] = decode_integer(data, val_offset, val_length)

    # Error Index
    tag, val_offset, val_length, offset = read_tlv(data, offset)
    result["error_index"] = decode_integer(data, val_offset, val_length)

    # Varbind List
    tag, vbl_offset, vbl_length, _ = read_tlv(data, offset)
    result["varbinds"] = parse_varbinds(data, vbl_offset, vbl_offset + vbl_length)


def parse_trap(data: bytes, sender_ip: str = "unknown") -> dict:
    """
    Parse any SNMP trap UDP payload — v1, v2c Inform, or v2c Trap.

    Returns a structured dict. Fields vary slightly by PDU type:
      All types   : sender_ip, timestamp, version, community, pdu_type, varbinds, parse_error
      v2c only    : request_id, error_status, error_index
      v1 only     : enterprise, agent_addr, generic_trap, specific_trap, timestamp_ticks
    """
    result = {
        "sender_ip":       sender_ip,
        "timestamp":       datetime.datetime.now().isoformat(timespec="seconds"),
        "version":         None,
        "community":       None,
        "pdu_type":        None,
        "pdu_tag_offset":  None,   # byte offset of PDU tag — used to build ACK
        # v2c fields
        "request_id":      None,
        "error_status":    None,
        "error_index":     None,
        # v1-only fields
        "enterprise":      None,
        "agent_addr":      None,
        "generic_trap":    None,
        "specific_trap":   None,
        "timestamp_ticks": None,
        # common
        "varbinds":        [],
        "parse_error":     None,
    }

    try:
        offset = 0

        # ── Outer SEQUENCE wrapper ───────────────────────────────
        tag, seq_offset, seq_length, _ = read_tlv(data, offset)
        if tag != TAG_SEQUENCE:
            raise ValueError(f"Expected outer SEQUENCE (0x30), got 0x{tag:02X}")
        offset = seq_offset

        # ── SNMP Version ─────────────────────────────────────────
        tag, val_offset, val_length, offset = read_tlv(data, offset)
        raw_ver = decode_integer(data, val_offset, val_length)
        result["version"] = {0: "v1", 1: "v2c", 3: "v3"}.get(raw_ver, f"unknown({raw_ver})")

        # ── Community String ─────────────────────────────────────
        tag, val_offset, val_length, offset = read_tlv(data, offset)
        result["community"] = decode_octet_string(data, val_offset, val_length)

        # ── PDU — branch by type ─────────────────────────────────
        pdu_tag_offset = offset                             # save position of PDU tag byte
        pdu_tag, pdu_offset, pdu_length, _ = read_tlv(data, offset)
        result["pdu_type"]       = TAG_NAMES.get(pdu_tag, f"0x{pdu_tag:02X}")
        result["pdu_tag_offset"] = pdu_tag_offset

        if pdu_tag == TAG_PDU_V1_TRAP:
            parse_v1_trap_pdu(data, pdu_offset, result)

        elif pdu_tag in (TAG_PDU_V2_TRAP, TAG_PDU_INFORM):
            parse_v2_pdu(data, pdu_offset, result)

        else:
            raise ValueError(
                f"Unexpected PDU type 0x{pdu_tag:02X}. "
                f"Expected 0xA4 (v1 Trap), 0xA6 (v2 Inform), or 0xA7 (v2 Trap)."
            )

    except Exception as e:
        result["parse_error"] = f"{type(e).__name__}: {e}"

    return result


# ─────────────────────────────────────────────────────────────────
#  Pretty Printer
# ─────────────────────────────────────────────────────────────────

def print_trap(trap: dict) -> None:
    """Print a decoded trap in a clean, human-readable format."""
    W = 62
    print("─" * W)
    print(f"  SNMP TRAP")
    print(f"  From      : {trap['sender_ip']}")
    print(f"  At        : {trap['timestamp']}")
    print(f"  Version   : {trap['version']}")
    print(f"  Community : {trap['community']}")
    print(f"  PDU Type  : {trap['pdu_type']}")

    # v2c-specific fields
    if trap["request_id"] is not None:
        print(f"  Request ID: {trap['request_id']}")

    # v1-specific fields
    if trap["enterprise"] is not None:
        print(f"  Enterprise: {trap['enterprise']}")
        print(f"  Agent Addr: {trap['agent_addr']}")
        print(f"  Generic   : {trap['generic_trap']}")
        print(f"  Specific  : {trap['specific_trap']}")
        print(f"  Uptime    : {trap['timestamp_ticks']}")

    if trap["parse_error"]:
        print(f"\n  ⚠  Parse error: {trap['parse_error']}")
    else:
        print(f"\n  Varbinds ({len(trap['varbinds'])}):")
        if not trap["varbinds"]:
            print("    (none)")
        for i, vb in enumerate(trap["varbinds"], 1):
            name = f"  ← {vb['oid_name']}" if vb["oid_name"] else ""
            print(f"    [{i}] OID   : {vb['oid']}{name}")
            print(f"        Type  : {vb['value_type']}")
            print(f"        Value : {vb['value']}")
            print()

    print("─" * W)
    print()


# ─────────────────────────────────────────────────────────────────
#  BER Encoder  (only what's needed to build an InformRequest ACK)
# ─────────────────────────────────────────────────────────────────

def encode_length(n: int) -> bytes:
    """
    Encode a BER length field.
    Short form (0-127)  : one byte
    Long form  (128+)   : 0x80|n_bytes followed by the length big-endian
    """
    if n <= 127:
        return bytes([n])
    # How many bytes do we need to express n?
    length_bytes = []
    while n:
        length_bytes.append(n & 0xFF)
        n >>= 8
    length_bytes.reverse()
    return bytes([0x80 | len(length_bytes)] + length_bytes)


def encode_tlv(tag: int, value: bytes) -> bytes:
    """Wrap a value in a BER TLV envelope: tag + length + value."""
    return bytes([tag]) + encode_length(len(value)) + value


def encode_integer(n: int) -> bytes:
    """
    BER-encode a signed integer.
    Minimum number of bytes, big-endian, two's complement.
    """
    if n == 0:
        return encode_tlv(TAG_INTEGER, b'\x00')

    # Build the byte representation
    value_bytes = []
    negative = n < 0
    working  = n if n >= 0 else ~n          # work with positive magnitude

    while working:
        value_bytes.append(working & 0xFF)
        working >>= 8

    value_bytes.reverse()

    if negative:
        # Two's complement — flip bits and add 1
        value_bytes = [b ^ 0xFF for b in value_bytes]
        carry = 1
        for i in range(len(value_bytes) - 1, -1, -1):
            total = value_bytes[i] + carry
            value_bytes[i] = total & 0xFF
            carry = total >> 8

    # Ensure no ambiguous sign — positive numbers must not have high bit set
    if not negative and (value_bytes[0] & 0x80):
        value_bytes.insert(0, 0x00)
    if negative and not (value_bytes[0] & 0x80):
        value_bytes.insert(0, 0xFF)

    return encode_tlv(TAG_INTEGER, bytes(value_bytes))


def encode_octet_string(s: str) -> bytes:
    """BER-encode a UTF-8 string as OCTET STRING."""
    return encode_tlv(TAG_OCTET_STRING, s.encode("utf-8"))


def encode_sequence(content: bytes) -> bytes:
    """Wrap content bytes in a BER SEQUENCE."""
    return encode_tlv(TAG_SEQUENCE, content)


def build_inform_ack(raw_data: bytes, pdu_tag_offset: int) -> bytes:
    """
    Build an RFC 3416 compliant Response-PDU to acknowledge an InformRequest.

    RFC 3416 §4.2.7 requires the Response-PDU to contain the EXACT SAME
    varbinds as the InformRequest — not an empty list.

    The simplest correct approach: copy the original raw bytes and change
    just the PDU type byte from 0xA6 (InformRequest) to 0xA2 (Response-PDU).
    Everything else — request_id, error_status, error_index, varbinds — stays
    byte-for-byte identical, which is exactly what the RFC requires.
    """
    ack = bytearray(raw_data)
    ack[pdu_tag_offset] = 0xA2   # InformRequest (0xA6) → Response-PDU (0xA2)
    return bytes(ack)


# ─────────────────────────────────────────────────────────────────
#  Offline Test — real bytes captured from ComAp PLC via titan_udp
# ─────────────────────────────────────────────────────────────────

# This is the exact first packet captured: 177 bytes from 62.169.230.178
CAPTURED_PACKET = bytes.fromhex(
    "3081AE020101040670"
    "75626C6963A681A002"
    "0101020100020100308194300F06"
    "082B06010201010300"
    "430335353D301C060A"
    "2B060106030101040100060E2B06"
    "0104018181DF5A1D00"  # NOTE: adjust if hex differs from your capture
    "C4808008301606"
    "0C2B060104018181DF5A1D060100"
    "04063132324B5641"
    "30180"
    "60C2B060104018181"
    "DF5A1D0602000408"
    "323630393031304530"
    "31060C2B060104018181DF5A1D06"
    "03000421436162696E"
    "20456D657267656E63"
    "7920537470702D4C32"
    "2D41637469766174656"
    "4"
)

# Clean bytes directly from the hexdump — easier to verify line by line
CAPTURED_PACKET = bytes([
    0x30,0x81,0xAE,0x02,0x01,0x01,0x04,0x06,0x70,0x75,0x62,0x6C,0x69,0x63,0xA6,0x81,
    0xA0,0x02,0x01,0x01,0x02,0x01,0x00,0x02,0x01,0x00,0x30,0x81,0x94,0x30,0x0F,0x06,
    0x08,0x2B,0x06,0x01,0x02,0x01,0x01,0x03,0x00,0x43,0x03,0x35,0x35,0x3D,0x30,0x1C,
    0x06,0x0A,0x2B,0x06,0x01,0x06,0x03,0x01,0x01,0x04,0x01,0x00,0x06,0x0E,0x2B,0x06,
    0x01,0x04,0x01,0x81,0xDF,0x5A,0x1D,0x00,0xC4,0x80,0x80,0x08,0x30,0x16,0x06,0x0C,
    0x2B,0x06,0x01,0x04,0x01,0x81,0xDF,0x5A,0x1D,0x06,0x01,0x00,0x04,0x06,0x31,0x33,
    0x32,0x4B,0x56,0x41,0x30,0x18,0x06,0x0C,0x2B,0x06,0x01,0x04,0x01,0x81,0xDF,0x5A,
    0x1D,0x06,0x02,0x00,0x04,0x08,0x32,0x36,0x30,0x39,0x30,0x31,0x30,0x45,0x30,0x31,
    0x06,0x0C,0x2B,0x06,0x01,0x04,0x01,0x81,0xDF,0x5A,0x1D,0x06,0x03,0x00,0x04,0x21,
    0x43,0x61,0x62,0x69,0x6E,0x20,0x45,0x6D,0x65,0x72,0x67,0x65,0x6E,0x63,0x79,0x20,
    0x53,0x74,0x6F,0x70,0x2D,0x4C,0x32,0x2D,0x41,0x63,0x74,0x69,0x76,0x61,0x74,0x65,
    0x64,
])


def run_test():
    """Parse the real captured ComAp packet and print the result."""
    print("=" * 62)
    print("  OFFLINE TEST — ComAp packet captured via titan_udp.py")
    print("=" * 62)
    print()
    trap = parse_trap(CAPTURED_PACKET, sender_ip="62.169.230.178")
    print_trap(trap)
    print("  Once you see the OIDs decoded above, copy them into")
    print("  the OID_NAMES dictionary at the top of this file.")
    print()


# ─────────────────────────────────────────────────────────────────
#  UDP Listener — live mode
# ─────────────────────────────────────────────────────────────────

def run_listener(port: int) -> None:
    """Bind to UDP port and parse every incoming trap."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        sock.bind(("0.0.0.0", port))
    except PermissionError:
        print(f"[ERROR] Permission denied on port {port}.")
        print("        Ports below 1024 require root.")
        print(f"        Try: sudo python snmp_parser.py --port {port}")
        sys.exit(1)
    except OSError as e:
        print(f"[ERROR] Could not bind to port {port}: {e}")
        sys.exit(1)

    print(f"[SNMP Parser] Listening on UDP port {port}")
    print("[SNMP Parser] Waiting for traps... (Ctrl+C to stop)\n")

    try:
        while True:
            data, (sender_ip, sender_port) = sock.recvfrom(65535)
            print(f"sender_port = {sender_port}")
            trap = parse_trap(data, sender_ip)

            # ── Auto-ACK for v2 Inform ──────────────────────────
            # Only runs when PLC uses v2 Inform — skipped for v1 Trap and v2 Notific
            if trap["pdu_type"].startswith("SNMPv2c-InformRequest"):
                try:
                    ack = build_inform_ack(data, trap["pdu_tag_offset"])
                    sock.sendto(ack, (sender_ip, sender_port))
                    print(f"  [ACK] → {sender_ip}:{sender_port}  request_id={trap['request_id']}")
                except Exception as e:
                    print(f"  [ACK ERROR] Failed to send ACK: {e}")

            print_trap(trap)

    except KeyboardInterrupt:
        print("\n[SNMP Parser] Stopped.")
    finally:
        sock.close()


# ─────────────────────────────────────────────────────────────────
#  Entry Point
# ─────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="SNMP Trap Parser — pure Python, no dependencies",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "--port", type=int, default=162,
        help="UDP port to listen on (default: 162)"
    )
    parser.add_argument(
        "--test", action="store_true",
        help="Parse the hardcoded captured ComAp packet offline (no socket needed)"
    )
    args = parser.parse_args()

    if args.test:
        run_test()
    else:
        run_listener(args.port)
