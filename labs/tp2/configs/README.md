# TP2 configuration notes

This directory contains configuration fragments that can be represented safely and exactly from the validated lab evidence.

## Included

- `50-user-exec.rules`: auditd EXECVE tracking;
- `60-user-perms.rules`: successful umask/chmod-family tracking;
- `kernel-modules-lock.service`: delayed irreversible module lock;
- `user-perms-monitor.service`: audit-event consumer;
- `authentication-examples.md`: sanitized PAM, SSH and sudo excerpts.

## Not included as a full file

The complete `99-anssi-hardening.conf` is not reconstructed from memory or partial excerpts. The final lab evidence confirms a targeted 45-key runtime check and a persistent sysctl configuration, but this repository only versions configuration that could be recovered exactly enough to avoid inventing values.

The read-only audit collector still contains the exact list of 45 targeted sysctl keys used by the TP2 audit.
