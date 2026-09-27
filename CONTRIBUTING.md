# Contributing

This repository is primarily a personal lab and portfolio project.

Contributions should preserve three principles:

1. do not turn undocumented assumptions into claims of successful hardening;
2. keep secret-bearing or third-party course material out of Git;
3. keep scripts deterministic, reviewable and safe by default.

Before opening a change:

```bash
bash -n labs/tp1/scripts/*.sh
bash -n labs/tp2/scripts/*.sh
shellcheck --severity=error labs/tp1/scripts/*.sh labs/tp2/scripts/*.sh
```

Documentation changes should keep the distinction between required, configured, observed and demonstrated behavior.
