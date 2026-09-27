#!/usr/bin/env bash
set -u

clean() {
    local value="${1:-unknown}"
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"
    printf '%.255s' "$value"
}

printf '%s user=%s source=%s\n' \
    "$(date '+%F %T%z')" \
    "$(clean "${PAM_USER:-unknown}")" \
    "$(clean "${PAM_RHOST:-unknown}")" \
    >> /var/log/user_ssh.log
