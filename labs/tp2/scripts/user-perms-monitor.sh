#!/usr/bin/env bash
set -u

CHECKPOINT="/var/lib/user-perms-monitor/checkpoint"
LOG="/var/log/user_perms.log"

while true; do
    /usr/bin/ausearch \
        --input-logs \
        -k user_perms \
        --checkpoint "$CHECKPOINT" \
        -i >> "$LOG" 2>/dev/null || true
    sleep 2
done
