# TP2 audit archive

The versioned collector [collect_tp2_audit.sh](../../labs/tp2/scripts/collect_tp2_audit.sh) creates a read-only snapshot under `/tmp` and then archives it.

Typical output:

```text
TP-Hardening-2-audit-YYYYMMDD-HHMMSS/
├── audit.txt
├── README_AUDIT.md
├── manifest.txt
├── errors.txt
├── configs/
└── commands/
```

The collector separates technical collection errors from missing configuration.

It explicitly avoids reading or copying:

- private keys;
- MFA seed contents;
- password hashes;
- LUKS key material;
- tokens;
- full environment dumps;
- large raw logs.

Generated archives are intentionally excluded from Git. Review and sanitize them before any external sharing.
