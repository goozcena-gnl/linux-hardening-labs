# Validation and known gaps

## TP1

The final TP1 evidence documented:

- required system partitions and mount options;
- successful UEFI boot;
- active swap and hardened pseudo-filesystem mounts;
- `localadm` and `rescue` sudo behavior;
- dedicated `/var/log/sudo.log`;
- root password lock;
- SSH TOTP login for `localadm`;
- SSH denial for root and rescue;
- LUKS2 + LVM + ext4 stack for `/data`;
- `LABEL=KEY`, root-owned key file and multiple LUKS keyslots;
- automatic `/data` activation with the key device present;
- successful degraded boot without the key device;
- successful recovery using `get_data.sh`;
- GRUB authentication tests.

## TP2

### Demonstrated

- auditd active, `enabled 1`, `lost 0` at test time;
- persistent EXECVE rules for `auid >= 1000`;
- service start/stop events present;
- an actual `/usr/bin/date` EXECVE event present;
- kernel hardening checker reported no difference in the final run;
- deliberate kernel-setting changes were detected and written to `kernel_modif.log`;
- `kernel.modules_disabled=1` after required module load;
- `modprobe dummy` denied;
- password-quality settings present, including `enforce_for_root`;
- faillock configured for three failures and 900-second unlock;
- SSH effective configuration requires public key + PAM interactive step;
- successful key + OTP SSH login;
- SSH without key denied;
- `pam_exec` SSH-attempt logging demonstrated;
- localadm sudo OTP demonstrated;
- umask `0077` demonstrated with file mode 600 and directory mode 700;
- `/boot` mounted read-only and write denied;
- audit rules for successful `umask` and chmod-family syscalls;
- `user-perms-monitor` log entries for the tested changes;
- post-reboot LUKS2/LVM/`/data` state preserved.

### Not fully demonstrated

- auditd `USER_LOGIN` / `USER_LOGOUT` evidence was missing;
- the configured 08:00–20:00 `pam_time` rule had a positive in-window test but no demonstrated out-of-window denial;
- sudo OTP was scoped to `localadm`; `rescue` retained the normal sudo PAM service;
- the kernel comparison script was demonstrated on demand, not as continuous monitoring;
- the separate ANSSI kernel reference is not redistributed here, so the repository cannot independently prove that every value exactly matches that document.

These limitations are intentional parts of the portfolio: evidence quality matters more than claiming 100% completion.
