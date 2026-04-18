#!/usr/bin/env bash

decode_pdu() {
    local pdu="$1"
    local bytes=($pdu)
    local count=${#bytes[@]}

    if [ $count -lt 1 ]; then
        echo "No bytes provided."
        return 1
    fi

    # Convert all bytes to integers
    for ((i=0; i<count; i++)); do
        b[$i]=$((16#${bytes[$i]}))
    done

    echo "=== 8-bit bytes ==="
    for ((i=0; i<count; i++)); do
        printf "b[%d] = %3d (0x%02X)\n" $i ${b[$i]} ${b[$i]}
    done

    echo
    echo "=== 16-bit registers ==="

    if (( count >= 2 )); then
        for ((i=0; i<count-1; i+=2)); do
            A=${b[i]}
            B=${b[i+1]}

            be=$(( (A<<8) | B ))
            le=$(( (B<<8) | A ))

            printf "Register bytes %d-%d:\n" $i $((i+1))
            printf "  BE (AB) = %6d (0x%04X)\n" $be $be
            printf "  LE (BA) = %6d (0x%04X)\n" $le $le
            echo
        done
    else
        echo "Not enough bytes for 16‑bit registers."
    fi

    echo
    echo "=== 32-bit integers ==="
    echo "ABCD = Big‑Endian (A=MSB, D=LSB)"
    echo "CDAB = Word‑swap (CD)(AB)"
    echo "BADC = Byte‑swap inside words (BA)(DC)"
    echo "DCBA = Little‑Endian (full reverse)"
    echo

    if (( count >= 4 )); then
        for ((i=0; i<count-3; i+=4)); do
            A=${b[i]}; B=${b[i+1]}; C=${b[i+2]}; D=${b[i+3]}

            ABCD=$(( (A<<24)|(B<<16)|(C<<8)|D ))
            CDAB=$(( (C<<24)|(D<<16)|(A<<8)|B ))
            BADC=$(( (B<<24)|(A<<16)|(D<<8)|C ))
            DCBA=$(( (D<<24)|(C<<16)|(B<<8)|A ))

            printf "Bytes %d-%d:\n" $i $((i+3))
            printf "Big‑Endian (A=MSB, D=LSB) - (A B C D)       = %12u (0x%08X)\n" $ABCD $ABCD
            printf "Word‑swap (CD)(AB)  - (C D A B)             = %12u (0x%08X)\n" $CDAB $CDAB
            printf "Byte‑swap inside words (BA)(DC) - (B A D C) = %12u (0x%08X)\n" $BADC $BADC
            printf "Little‑Endian (full reverse) - (D C B A)    = %12u (0x%08X)\n" $DCBA $DCBA
            echo
        done
    else
        echo "Not enough bytes for 32‑bit values."
    fi

    echo
    echo "=== Float32 (IEEE754) ==="
    echo "Using same byte orders as above."
    echo

    float_bytes() {
        printf '%b' "\\x$(printf '%02X' $1)\\x$(printf '%02X' $2)\\x$(printf '%02X' $3)\\x$(printf '%02X' $4)" \
        | od -t f4 -An
    }

    if (( count >= 4 )); then
        for ((i=0; i<count-3; i+=4)); do
            A=${b[i]}; B=${b[i+1]}; C=${b[i+2]}; D=${b[i+3]}

            printf "Bytes %d-%d:\n" $i $((i+3))
            printf "Big‑Endian (A=MSB, D=LSB) - ABCD (A B C D)  : "; float_bytes $A $B $C $D
            printf "Word‑swap (CD)(AB) - (C D A B)              : "; float_bytes $C $D $A $B
            printf "Byte‑swap inside words (BA)(DC) - (B A D C) : "; float_bytes $B $A $D $C
            printf "Little‑Endian (full reverse) - (D C B A)    : "; float_bytes $D $C $B $A
            echo
        done
    else
        echo "Not enough bytes for float32."
    fi

    echo
    echo "=== ASCII (printable only) ==="

    ascii=""
    for ((i=0; i<count; i++)); do
        c=${b[$i]}
        if (( c >= 32 && c <= 126 )); then
            ascii+=$(printf '%b' "\\x$(printf '%02X' $c)")
        else
            ascii+="."
        fi
    done

    echo "$ascii"
}

decode_pdu "$1"
