#!/usr/bin/env python3
import os
import subprocess

LOCAL_DIR = "/home/gv/Desktop/PythonTests/smtp-python-scripts/smtp-mitm-proxy/"
REMOTE_HOST = "cloudzy"
REMOTE_DIR = "/home/gv/pytests/"

def list_local():
    paths = []
    for root, dirs, files in os.walk(LOCAL_DIR):
        for d in dirs:
            rel = os.path.relpath(os.path.join(root, d), LOCAL_DIR)
            paths.append(rel + "/")
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), LOCAL_DIR)
            paths.append(rel)
    return sorted(paths)

def list_remote():
    cmd = [
        "ssh", REMOTE_HOST,
        f"cd {REMOTE_DIR} && find . -type d -printf '%P/' -o -type f -printf '%P\n'"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    return sorted(lines)

def main():
    local = set(list_local())
    remote = set(list_remote())

    only_local = sorted(local - remote)
    only_remote = sorted(remote - local)
    common = sorted(local & remote)

    print("\n=== ONLY IN LOCAL ===")
    for item in only_local:
        print("  ", item)

    print("\n=== ONLY IN REMOTE ===")
    for item in only_remote:
        print("  ", item)

    print("\n=== IN BOTH ===")
    for item in common:
        print("  ", item)

    print("\nDone.")

if __name__ == "__main__":
    main()
