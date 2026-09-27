# Security model

## Goals

The lab focuses on reducing common local and remote attack paths on a standalone Linux VM:

- limit privilege exposure;
- reduce executable/writable surface;
- prevent direct root remote login;
- strengthen administrator authentication;
- protect application data at rest;
- make privileged activity easier to trace;
- make selected kernel/network hardening persistent;
- detect selected permission changes.

## Non-goals

This repository is not:

- a universal Linux baseline;
- a production-ready configuration-management role;
- an ANSSI/CIS compliance scanner;
- an EDR;
- a SIEM;
- a substitute for centralized identity;
- a guarantee against local root compromise.

## Trust boundaries

### KEY device

The removable/simulated `LABEL=KEY` device is treated as a secret-bearing asset. The real `data.key` is never committed.

### MFA data

Google Authenticator seed files and recovery codes are never collected. The TP2 audit collector records file metadata only.

### Audit output

Audit archives can expose hostnames, package versions, usernames, paths and configuration. They should be reviewed before sharing publicly.

### Git repository

Only sanitized scripts, examples and documentation belong here. Raw `/etc/shadow`, private keys, tokens, seed files, key material and unreviewed archives are prohibited.

## Lockout risk

Changes to PAM, SSH, sudo and GRUB can remove administrative access. In a real environment, use an out-of-band console and preserve a tested recovery procedure before applying them.
