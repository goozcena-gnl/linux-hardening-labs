# TP2 — Extended hardening

TP2 continues on the TP1 VM rather than starting from a new machine.

Main areas:

- kernel/sysctl hardening;
- PAM password, lockout and time controls;
- SSH public-key + OTP authentication;
- sudo OTP for the main administrator;
- auditd event collection;
- default umask and read-only `/boot`;
- permission-change tracking;
- post-reboot verification of TP1 encrypted storage.

See [implementation.md](implementation.md) and the repository-wide [validation notes](../validation.md).
