#!/usr/bin/env bash
set -euo pipefail

CRYPT_NAME="data_crypt"
CRYPT_DEVICE="/dev/sdb1"
VG_NAME="vg_data"
LV_DEVICE="/dev/mapper/vg_data-lv_data"
DATA_MOUNT="/data"

# Nothing to do when /data is already mounted from the expected LV.
if findmnt -rn -M "$DATA_MOUNT" -S "$LV_DEVICE" >/dev/null; then
    exit 0
fi

# Refuse to overlay an unrelated filesystem.
if mountpoint -q "$DATA_MOUNT"; then
    echo "ERROR: $DATA_MOUNT is already used by another filesystem." >&2
    exit 1
fi

if ! cryptsetup status "$CRYPT_NAME" >/dev/null 2>&1; then
    while :; do
        KEY_DEVICE="$(blkid -L KEY || true)"
        if [[ -n "$KEY_DEVICE" ]]; then
            break
        fi
        echo "LABEL=KEY device not found; retrying in 2 seconds..." >&2
        sleep 2
    done

    KEY_MOUNT="$(mktemp -d /run/get_data-key.XXXXXX)"
    cleanup() {
        umount "$KEY_MOUNT" 2>/dev/null || true
        rmdir "$KEY_MOUNT" 2>/dev/null || true
    }
    trap cleanup EXIT

    mount -o ro "$KEY_DEVICE" "$KEY_MOUNT"
    [[ -r "$KEY_MOUNT/data.key" ]] || {
        echo "ERROR: data.key not found on LABEL=KEY." >&2
        exit 1
    }

    cryptsetup open "$CRYPT_DEVICE" "$CRYPT_NAME"         --key-file "$KEY_MOUNT/data.key"

    cleanup
    trap - EXIT
fi

vgchange -ay "$VG_NAME" >/dev/null
mkdir -p "$DATA_MOUNT"
mount "$LV_DEVICE" "$DATA_MOUNT"

echo "[OK] $DATA_MOUNT is available."
