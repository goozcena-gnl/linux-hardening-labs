# Security policy

## Reporting a problem

If you find a secret, credential, private key, MFA seed, recovery code or other sensitive material committed to this repository, do not copy it into a public issue.

Contact the repository owner privately through an available GitHub contact channel.

## Repository data policy

The following must never be committed:

- private SSH keys;
- `.google_authenticator` contents;
- TOTP QR codes or recovery codes;
- LUKS key files;
- password hashes;
- tokens or API keys;
- unreviewed environment dumps;
- raw audit archives containing sensitive host data.

## CI/CD supply-chain scanning

GitHub Actions workflows are scanned with Poutine and uploaded as SARIF to GitHub Code Scanning. Poutine remains advisory; required merge checks continue to be `shell`, `docs`, and `secrets`.

## Scope

This repository is an educational hardening lab. Configuration examples require adaptation and testing before use on another system.
