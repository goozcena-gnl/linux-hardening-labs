#!/usr/bin/env bash

# Read-only collector for TP Hardening Linux level 2.
#
# Deliberately does not use "set -e": a secondary collection failure must be
# recorded in errors.txt without aborting the rest of the evidence snapshot.
set -u
set -o pipefail
umask 077

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: run this script with sudo." >&2
    exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
AUDIT_NAME="TP-Hardening-2-audit-${STAMP}"
AUDIT_DIR="/tmp/${AUDIT_NAME}"
ARCHIVE="/tmp/${AUDIT_NAME}.tar.gz"
AUDIT_FILE="${AUDIT_DIR}/audit.txt"
ERROR_FILE="${AUDIT_DIR}/errors.txt"
CONFIG_DIR="${AUDIT_DIR}/configs"
COMMAND_DIR="${AUDIT_DIR}/commands"

mkdir -p "${CONFIG_DIR}" "${COMMAND_DIR}"
: >"${AUDIT_FILE}"
: >"${ERROR_FILE}"

error() {
    printf '[COLLECTION ERROR] %s\n' "$*" >>"${ERROR_FILE}"
}

section() {
    printf '\n===== %s =====\n\n' "$1" >>"${AUDIT_FILE}"
}

capture() {
    local title=$1 output=$2 command=$3
    local stderr_file="${AUDIT_DIR}/.stderr"
    {
        printf '### %s\n' "${title}"
        printf '### COMMAND: %s\n' "${command}"
    } >"${output}"
    if ! bash -o pipefail -c "${command}" >>"${output}" 2>"${stderr_file}"; then
        error "${title} — command failed: ${command} — $(tr '\n' ' ' <"${stderr_file}")"
    elif [[ -s "${stderr_file}" ]]; then
        error "${title} — warning: $(tr '\n' ' ' <"${stderr_file}")"
    fi
    rm -f "${stderr_file}"
    printf '\n' >>"${output}"
    cat "${output}" >>"${AUDIT_FILE}"
}

record_absence() {
    printf '[ABSENT ON VM] %s\n' "$1" >>"${AUDIT_FILE}"
}

copy_config() {
    local source=$1 relative=$2 destination
    destination="${CONFIG_DIR}/${relative}"
    if [[ ! -e "${source}" && ! -L "${source}" ]]; then
        record_absence "${source}"
        return 0
    fi
    if [[ ! -f "${source}" ]]; then
        error "${source} exists but is not a regular file; content not copied"
        return 0
    fi
    mkdir -p "$(dirname "${destination}")"
    if cp --dereference -- "${source}" "${destination}" 2>>"${ERROR_FILE}"; then
        chmod 0600 "${destination}"
        stat -Lc '%n | owner=%U group=%G mode=%a size=%s mtime=%y' -- "${source}" >>"${CONFIG_DIR}/file_metadata.txt" 2>>"${ERROR_FILE}" || true
    else
        error "unable to copy: ${source}"
    fi
}

copy_globbed_configs() {
    local base=$1 pattern=$2 destination_base=$3 source
    [[ -d "${base}" ]] || return 0
    while IFS= read -r -d '' source; do
        copy_config "${source}" "${destination_base}/${source#"${base}"/}"
    done < <(find "${base}" -maxdepth 1 \( -type f -o -type l \) -name "${pattern}" -print0 2>>"${ERROR_FILE}")
}

redact_stream() {
    sed -E \
        -e 's/([[:alnum:]_]*(PASSWORD|PASSWD|SECRET|TOKEN|KEY|CREDENTIAL)[[:alnum:]_]*)([[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1\3<REDACTED>/Ig' \
        -e 's/(Authorization:[[:space:]]*(Bearer|Basic)[[:space:]]+)[^[:space:]]+/\1<REDACTED>/Ig' \
        -e 's/([[:digit:]]{1,3}\.){3}[[:digit:]]{1,3}/<IP>/g' \
        -e 's/[[:xdigit:]]{40,}/<LONG_HEX_REDACTED>/g'
}

copy_discovered_text() {
    local source=$1 destination
    destination="${CONFIG_DIR}/discovered${source}"
    [[ -f "${source}" && ! -L "${source}" ]] || return 0
    if [[ $(stat -c '%s' -- "${source}" 2>/dev/null || echo 9999999) -gt 262144 ]]; then
        error "candidate file too large; content not copied: ${source}"
        return 0
    fi
    if grep -Iq . "${source}" 2>/dev/null &&
       ! grep -qE 'BEGIN ([A-Z ]+)?PRIVATE KEY' "${source}" 2>/dev/null; then
        mkdir -p "$(dirname "${destination}")"
        if redact_stream <"${source}" >"${destination}"; then
            chmod 0600 "${destination}"
            stat -Lc '%n | owner=%U group=%G mode=%a size=%s mtime=%y' -- "${source}" >>"${CONFIG_DIR}/file_metadata.txt" 2>>"${ERROR_FILE}" || true
        else
            error "unable to create filtered copy: ${source}"
        fi
    else
        error "candidate is binary or a private key; content excluded: ${source}"
    fi
}

collect_log_evidence() {
    local source=$1 label=$2 output
    output="${COMMAND_DIR}/${label}.txt"
    {
        printf '### LOG: %s\n' "${source}"
        if [[ -e "${source}" ]]; then
            stat -Lc 'owner=%U group=%G mode=%a size=%s mtime=%y' -- "${source}"
            printf '\n### Last 30 filtered lines\n'
            tail -n 30 -- "${source}" 2>>"${ERROR_FILE}" | redact_stream
        else
            printf '[ABSENT ON VM] %s\n' "${source}"
        fi
    } >"${output}"
    cat "${output}" >>"${AUDIT_FILE}"
    printf '\n' >>"${AUDIT_FILE}"
}

collect_google_authenticator_metadata() {
    local output="${COMMAND_DIR}/google_authenticator_metadata.txt"
    {
        printf '### Metadata only — MFA secrets are never read\n'
        find /root /home -xdev -maxdepth 3 -type f -name '.google_authenticator' -printf '%p | owner=%u group=%g mode=%m size=%s mtime=%TY-%Tm-%TdT%TH:%TM:%TS%Tz\n' 2>>"${ERROR_FILE}" || true
    } >"${output}"
    cat "${output}" >>"${AUDIT_FILE}"
    printf '\n' >>"${AUDIT_FILE}"
}

collect_custom_candidates() {
    local refs="${COMMAND_DIR}/custom_tracking_references.txt"
    local candidates="${AUDIT_DIR}/.candidates"
    local roots=() root source
    for root in /usr/local/sbin /usr/local/bin /etc/systemd/system /etc/cron.d /etc/cron.daily /etc/cron.hourly; do
        [[ -d "${root}" ]] && roots+=("${root}")
    done
    {
        printf '### Targeted references to TP2 custom mechanisms\n'
        if (("${#roots[@]}")); then
            grep -RInE --binary-files=without-match 'kernel_modif\.log|user_ssh\.log|user_perms\.log|pam_exec\.so|modules_disabled' "${roots[@]}" 2>>"${ERROR_FILE}" | redact_stream || true
        fi
    } >"${refs}"
    cat "${refs}" >>"${AUDIT_FILE}"
    printf '\n' >>"${AUDIT_FILE}"

    : >"${candidates}"
    if (("${#roots[@]}")); then
        grep -RIlE --binary-files=without-match 'kernel_modif\.log|user_ssh\.log|user_perms\.log|pam_exec\.so|modules_disabled' "${roots[@]}" 2>/dev/null | sort -u >"${candidates}" || true
    fi
    while IFS= read -r source; do
        [[ -n "${source}" ]] && copy_discovered_text "${source}"
    done <"${candidates}"
    rm -f "${candidates}"
}

collect_packages() {
    local output="${COMMAND_DIR}/relevant_packages.txt"
    {
        printf '### Relevant package versions only\n'
        if command -v dpkg-query >/dev/null 2>&1; then
            dpkg-query -W -f='${binary:Package}\t${Version}\n' openssh-server libpam0g libpam-modules libpam-pwquality libpam-google-authenticator auditd sudo systemd 2>/dev/null || true
        elif command -v rpm >/dev/null 2>&1; then
            rpm -q openssh-server pam libpwquality google-authenticator audit sudo systemd 2>/dev/null || true
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Q openssh pam libpwquality libpam-google-authenticator audit sudo systemd 2>/dev/null || true
        else
            printf 'Supported package manager not detected.\n'
        fi
    } >"${output}"
    cat "${output}" >>"${AUDIT_FILE}"
    printf '\n' >>"${AUDIT_FILE}"
}

SYSCTL_KEYS=(
    net.ipv4.ip_forward
    net.ipv4.conf.all.rp_filter
    net.ipv4.conf.default.rp_filter
    net.ipv4.conf.all.send_redirects
    net.ipv4.conf.default.send_redirects
    net.ipv4.conf.all.accept_source_route
    net.ipv4.conf.default.accept_source_route
    net.ipv4.conf.all.accept_redirects
    net.ipv4.conf.all.secure_redirects
    net.ipv4.conf.default.accept_redirects
    net.ipv4.conf.default.secure_redirects
    net.ipv4.conf.all.log_martians
    net.ipv4.tcp_rfc1337
    net.ipv4.icmp_ignore_bogus_error_responses
    net.ipv4.ip_local_port_range
    net.ipv4.tcp_syncookies
    net.ipv6.conf.all.router_solicitations
    net.ipv6.conf.default.router_solicitations
    net.ipv6.conf.all.accept_ra_rtr_pref
    net.ipv6.conf.default.accept_ra_rtr_pref
    net.ipv6.conf.all.accept_ra_pinfo
    net.ipv6.conf.default.accept_ra_pinfo
    net.ipv6.conf.all.accept_ra_defrtr
    net.ipv6.conf.default.accept_ra_defrtr
    net.ipv6.conf.all.autoconf
    net.ipv6.conf.default.autoconf
    net.ipv6.conf.all.accept_redirects
    net.ipv6.conf.default.accept_redirects
    net.ipv6.conf.all.accept_source_route
    net.ipv6.conf.default.accept_source_route
    net.ipv6.conf.all.max_addresses
    net.ipv6.conf.default.max_addresses
    kernel.sysrq
    fs.suid_dumpable
    fs.protected_symlinks
    fs.protected_hardlinks
    kernel.randomize_va_space
    vm.mmap_min_addr
    kernel.pid_max
    kernel.kptr_restrict
    kernel.dmesg_restrict
    kernel.perf_event_paranoid
    kernel.perf_event_max_sample_rate
    kernel.perf_cpu_time_max_percent
    kernel.modules_disabled
)

section "SYSTEM IDENTITY"
capture "Identity and versions" "${COMMAND_DIR}/system_identity.txt" "date --iso-8601=seconds; hostnamectl 2>/dev/null || hostname; uname -a; printf '\\n/etc/os-release\\n'; sed -n '1,80p' /etc/os-release 2>/dev/null; printf '\\nPID 1\\n'; ps -p 1 -o pid=,comm=,args="
capture "Local accounts without GECOS or password hashes" "${COMMAND_DIR}/local_accounts.txt" "awk -F: '{print \$1 \":uid=\" \$3 \":gid=\" \$4 \":shell=\" \$7}' /etc/passwd"

section "KERNEL AND SYSCTL — TARGETED EFFECTIVE VALUES"
{
    printf '### COMMAND: sysctl <45 targeted parameters>\n'
    for key in "${SYSCTL_KEYS[@]}"; do
        sysctl "${key}" 2>>"${ERROR_FILE}" || error "sysctl key unavailable: ${key}"
    done
    printf '\n### Currently loaded modules\n'
    if command -v lsmod >/dev/null 2>&1; then
        lsmod
    elif [[ -r /proc/modules ]]; then
        sed -n '1,200p' /proc/modules
    else
        printf '[UNAVAILABLE] Module list cannot be read in this environment.\n'
    fi
} >"${COMMAND_DIR}/sysctl_effective.txt"
cat "${COMMAND_DIR}/sysctl_effective.txt" >>"${AUDIT_FILE}"
printf '\n' >>"${AUDIT_FILE}"

section "SYSCTL — PERSISTENT CONFIGURATION"
copy_config /etc/sysctl.conf sysctl/etc/sysctl.conf
for root in /etc/sysctl.d /run/sysctl.d /usr/local/lib/sysctl.d /usr/lib/sysctl.d; do
    copy_globbed_configs "${root}" '*.conf' "sysctl${root}"
done
if [[ -d /lib/sysctl.d ]] &&
   [[ $(readlink -f /lib/sysctl.d) != $(readlink -f /usr/lib/sysctl.d 2>/dev/null || printf absent) ]]; then
    copy_globbed_configs /lib/sysctl.d '*.conf' sysctl/lib/sysctl.d
fi
if command -v systemd-sysctl >/dev/null 2>&1; then
    capture "Concatenated sysctl configuration without applying it" "${COMMAND_DIR}/sysctl_cat_config.txt" "systemd-sysctl --cat-config"
fi

section "PAM AND PASSWORD POLICY"
copy_globbed_configs /etc/pam.d '*' pam/etc/pam.d
copy_config /etc/security/pwquality.conf security/etc/security/pwquality.conf
copy_globbed_configs /etc/security/pwquality.conf.d '*.conf' security/etc/security/pwquality.conf.d
copy_config /etc/security/faillock.conf security/etc/security/faillock.conf
copy_config /etc/security/time.conf security/etc/security/time.conf
capture "Referenced PAM modules and options" "${COMMAND_DIR}/pam_references.txt" "grep -RInE -- 'pam_(pwquality|faillock|time|exec|google_authenticator|unix)\\.so|include|substack' /etc/pam.d /etc/security/pwquality.conf /etc/security/pwquality.conf.d /etc/security/faillock.conf /etc/security/time.conf 2>/dev/null || true"
if command -v pam-auth-update >/dev/null 2>&1; then
    capture "Active Debian PAM profiles" "${COMMAND_DIR}/pam_auth_update_status.txt" "pam-auth-update --status"
fi
capture "Date, time and timezone used by pam_time" "${COMMAND_DIR}/system_time.txt" "date --iso-8601=seconds; timedatectl show -p Timezone -p LocalRTC -p NTPSynchronized 2>/dev/null || true"

section "SSH — PERSISTENT AND EFFECTIVE CONFIGURATION"
copy_config /etc/ssh/sshd_config ssh/etc/ssh/sshd_config
copy_globbed_configs /etc/ssh/sshd_config.d '*.conf' ssh/etc/ssh/sshd_config.d
if command -v sshd >/dev/null 2>&1; then
    capture "SSH syntax validation" "${COMMAND_DIR}/sshd_syntax.txt" "sshd -t"
    capture "Effective global SSH configuration" "${COMMAND_DIR}/sshd_effective.txt" "sshd -T"
else
    error "sshd command absent"
fi
capture "SSH service state without journal" "${COMMAND_DIR}/ssh_service.txt" "for unit in sshd.service ssh.service; do systemctl show \"\$unit\" -p Id -p LoadState -p ActiveState -p SubState -p UnitFileState 2>/dev/null || true; done"
collect_google_authenticator_metadata

section "SSH ATTEMPT LOGGING"
if [[ -f /usr/local/sbin/log-ssh-attempt.sh ]]; then
    copy_discovered_text /usr/local/sbin/log-ssh-attempt.sh
else
    record_absence /usr/local/sbin/log-ssh-attempt.sh
fi
collect_log_evidence /var/log/user_ssh.log user_ssh_log

section "AUDITD — SERVICE, RULES AND EVENT TYPES"
copy_config /etc/audit/auditd.conf auditd/etc/audit/auditd.conf
copy_config /etc/audit/audit.rules auditd/etc/audit/audit.rules
copy_globbed_configs /etc/audit/rules.d '*.rules' auditd/etc/audit/rules.d
capture "auditd service state" "${COMMAND_DIR}/auditd_service.txt" "systemctl show auditd.service -p Id -p LoadState -p ActiveState -p SubState -p UnitFileState 2>/dev/null || true"
if command -v auditctl >/dev/null 2>&1; then
    capture "Effective auditd state" "${COMMAND_DIR}/auditctl_status.txt" "auditctl -s"
    capture "Loaded auditd rules" "${COMMAND_DIR}/auditctl_rules.txt" "auditctl -l"
else
    error "auditctl command absent"
fi
if command -v ausearch >/dev/null 2>&1; then
    capture "Targeted recent audit event type counts, without EXECVE content" "${COMMAND_DIR}/audit_event_type_counts.txt" "ausearch -m SERVICE_START,SERVICE_STOP,EXECVE,USER_LOGIN,USER_LOGOUT -ts recent --raw 2>/dev/null | awk '{for (i=1;i<=NF;i++) if (\$i ~ /^type=/) {sub(/^type=/,\"\",\$i); print \$i}}' | sort | uniq -c || true"
fi

section "DEFAULT UMASK"
copy_config /etc/login.defs umask/etc/login.defs
capture "Persistent umask references" "${COMMAND_DIR}/umask_references.txt" "grep -RInE -- '(^|[;[:space:]])umask[[:space:]]+' /etc/login.defs /etc/profile /etc/bash.bashrc /etc/bashrc /etc/profile.d /etc/pam.d 2>/dev/null || true"
capture "Collector process umask — context only" "${COMMAND_DIR}/collector_umask.txt" "umask"
capture "systemd default umask" "${COMMAND_DIR}/systemd_default_umask.txt" "systemctl show --property=DefaultUMask 2>/dev/null || true"

section "/BOOT — ACTIVE STATE, PERSISTENCE AND PERMISSIONS"
if [[ -f /etc/fstab ]]; then
    mkdir -p "${CONFIG_DIR}/boot/etc"
    awk '!/^[[:space:]]*#/ && ($2 == "/boot" || $2 == "/boot/efi")' /etc/fstab |
        redact_stream >"${CONFIG_DIR}/boot/etc/fstab_boot_entries.txt"
    chmod 0600 "${CONFIG_DIR}/boot/etc/fstab_boot_entries.txt"
    stat -Lc '%n | owner=%U group=%G mode=%a size=%s mtime=%y' /etc/fstab >>"${CONFIG_DIR}/file_metadata.txt" 2>>"${ERROR_FILE}" || true
else
    record_absence /etc/fstab
fi
capture "Active /boot mount" "${COMMAND_DIR}/boot_mount.txt" "findmnt --target /boot --output TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true; printf '\\nExact /boot mount\\n'; findmnt --mountpoint /boot --output TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true"
capture "/boot permissions and first level" "${COMMAND_DIR}/boot_permissions.txt" "namei -l /boot 2>/dev/null || true; printf '\\n'; stat -Lc '%n | owner=%U group=%G mode=%a type=%F' /boot 2>/dev/null || true; printf '\\nFirst level:\\n'; find /boot -xdev -maxdepth 1 -mindepth 1 -printf '%p | owner=%u group=%g mode=%m type=%y\\n' 2>/dev/null | sort"
if command -v getfacl >/dev/null 2>&1; then
    capture "/boot ACL" "${COMMAND_DIR}/boot_acl.txt" "getfacl -p /boot"
fi
capture "Optional /boot systemd unit" "${COMMAND_DIR}/boot_mount_unit.txt" "systemctl cat boot.mount 2>/dev/null || true"

section "UMASK AND CHMOD CHANGE TRACKING"
collect_log_evidence /var/log/user_perms.log user_perms_log

section "SUDO AND OTP"
copy_config /etc/pam.d/sudo sudo/etc/pam.d/sudo
copy_config /etc/sudoers sudo/etc/sudoers
copy_globbed_configs /etc/sudoers.d '*' sudo/etc/sudoers.d
if command -v visudo >/dev/null 2>&1; then
    capture "sudoers syntax validation" "${COMMAND_DIR}/visudo_check.txt" "visudo -c"
fi
capture "sudo PAM chain and OTP/pam_unix references" "${COMMAND_DIR}/sudo_pam_references.txt" "grep -RInE -- 'pam_(google_authenticator|unix)\\.so|include|substack' /etc/pam.d/sudo /etc/pam.d/system-auth /etc/pam.d/common-auth 2>/dev/null || true"

section "CUSTOM MECHANISMS — SCRIPTS, UNITS, TIMERS AND CRON"
collect_custom_candidates
capture "Candidate units and timers" "${COMMAND_DIR}/custom_units.txt" "systemctl list-unit-files --no-pager --no-legend 2>/dev/null | grep -Ei 'kernel|sysctl|perm|umask|chmod|audit|ssh' || true"
capture "Candidate running processes" "${COMMAND_DIR}/custom_processes.txt" "ps -eo user=,pid=,ppid=,lstart=,comm= | grep -Ei 'kernel_modif|user_perms|log-ssh|auditd' | grep -v '[g]rep' || true"
collect_log_evidence /var/log/kernel_modif.log kernel_modif_log

section "RELEVANT PACKAGES"
collect_packages

cat >"${AUDIT_DIR}/README_AUDIT.md" <<EOF
# TP Hardening Linux level 2 audit archive

- VM: $(hostname 2>/dev/null || printf 'unknown')
- Collected: $(date --iso-8601=seconds)
- Script: collect_tp2_audit.sh

This archive is a read-only snapshot of persistent configuration and active
state used for later TP2 evaluation. It is not itself a compliance report.

## Structure

- audit.txt: chronological evidence and commands;
- commands/: targeted command outputs;
- configs/: useful configuration copies and file metadata;
- errors.txt: technical collection errors, separate from non-compliance;
- manifest.txt: inventory and internal SHA-256 hashes.

Private keys, password hashes, MFA secrets, LUKS key material, tokens,
environment dumps and large raw logs are excluded. Short log excerpts are
filtered.
EOF

if [[ ! -s "${ERROR_FILE}" ]]; then
    printf 'No technical collection error recorded.\n' >"${ERROR_FILE}"
fi

{
    printf 'Audit: %s\n' "${AUDIT_NAME}"
    printf 'Date: %s\n' "$(date --iso-8601=seconds)"
    printf 'Hostname: %s\n' "$(hostname 2>/dev/null || printf 'unknown')"
    printf 'Distribution: %s\n' "$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-unknown}")"
    printf 'Kernel: %s\n' "$(uname -r)"
    printf 'Launched by: %s (uid=%s)\n' "${SUDO_USER:-$(id -un)}" "${SUDO_UID:-$(id -u)}"
    printf '\nFiles and SHA-256 (manifest.txt excluded from its own calculation):\n'
    (
        cd "${AUDIT_DIR}" || exit 1
        find . -type f ! -name manifest.txt -print0 | sort -z | xargs -0 sha256sum
    )
} >"${AUDIT_DIR}/manifest.txt"

if ! tar -C /tmp -czf "${ARCHIVE}" "${AUDIT_NAME}"; then
    echo "ERROR: unable to create archive." >&2
    exit 1
fi

sha256sum "${ARCHIVE}" >"${ARCHIVE}.sha256"
printf '\nAudit complete.\n\nDirectory:\n%s\n\nArchive:\n%s\n\nSHA256:\n' "${AUDIT_DIR}" "${ARCHIVE}"
cat "${ARCHIVE}.sha256"
