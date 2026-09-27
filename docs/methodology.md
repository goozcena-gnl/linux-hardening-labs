# Methodology

This repository separates **requirements**, **persistent configuration**, **runtime state** and **functional evidence**.

A configuration is not treated as proven merely because a file contains the expected value.

## Evidence model

For each control, the lab asks four questions:

1. **Requirement** — what behavior is expected?
2. **Persistent configuration** — what should survive reboot?
3. **Runtime state** — what is active now?
4. **Functional test** — can the behavior be demonstrated?

Examples:

- `PasswordAuthentication no` is persistent configuration; `sshd -T` confirms the effective SSH setting.
- `kernel.modules_disabled=1` is runtime state; a failed `modprobe dummy` demonstrates the consequence.
- `/boot` being declared read-only in `fstab` is not enough; `findmnt` and a failed write test confirm the active state.
- auditd rules are checked with both `auditctl -l` and actual `ausearch` output.

## Reboot testing

Reboot is part of the security test, not a final cosmetic check. It verifies that:

- LUKS/LVM still comes up correctly;
- required modules were loaded before the irreversible module lock;
- systemd units are enabled in the correct order;
- mount options are persistent;
- authentication changes did not lock out the administrator.

## Negative tests

Important controls include a failure-path test where practical:

- SSH root denied;
- SSH rescue denied;
- SSH without a public key denied in TP2;
- incorrect GRUB authentication denied;
- `/boot` write denied;
- `modprobe` denied after module locking;
- non-compliant password examples rejected by the password-quality tool.

Where a negative test was **not** demonstrated, the documentation says so explicitly.

## Audit archives

The audit collector is intentionally read-only. It collects a targeted snapshot of:

- configuration;
- effective state;
- service state;
- selected logs;
- package versions;
- file metadata.

It deliberately excludes private keys, MFA seed contents, password hashes, LUKS key files, tokens and large raw logs.

An audit-collection failure is recorded separately from a potential hardening failure.
