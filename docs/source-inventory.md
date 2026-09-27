# Source inventory and publication scope

The GitHub repository was reconstructed from the original TP requirements, final reports, audit material and scripts. Source files are treated as evidence inputs; they are not all suitable for public redistribution.

## Canonical inputs used

| Source | Role | Repository treatment |
| --- | --- | --- |
| TP1 assignment PDF | Requirement baseline | Summarized, not redistributed |
| TP2 assignment PDF | Requirement baseline | Summarized, not redistributed |
| Final TP1 report | Implementation and evidence record | Converted to Markdown, report not committed |
| Final TP2 report | Implementation and evidence record | Converted to Markdown, report not committed |
| `collect_tp2_audit.sh` | Read-only audit tool | Versioned as source code |
| TP1 `get_data.sh` excerpt | Recovery implementation | Versioned as source code |

## Intentionally excluded

- duplicate copies of the same TP1 assignment;
- intermediate Word/PDF report revisions;
- draft reports;
- audit scoring/working documents;
- raw audit `.tar.gz` archives;
- unreviewed screenshots;
- the real LUKS key file;
- Google Authenticator seed files, QR codes and recovery codes;
- private SSH keys;
- password hashes;
- local environment dumps.

## Why reports are not the primary interface

The repository documentation is Markdown-first so that a reviewer can understand the work directly in GitHub. Office/PDF reports remain historical deliverables, while the repository focuses on reproducible scripts, sanitized configuration examples, validation logic and known limitations.

## ANSSI reference

The TP2 assignment refers to a separate kernel-configuration recommendation document. An autonomous copy suitable for redistribution was not retained in this repository build. The project therefore documents the values and validation approach actually demonstrated by the lab without claiming independent ANSSI compliance.

## Visual evidence policy

The final TP1 and TP2 reports contain terminal screenshots used during assessment. For the public repository, representative results are published as **sanitized SVG transcripts** in `docs/assets/evidence/`.

These SVGs are not claimed to be raw screenshots. They reproduce only the relevant demonstrated output while removing unnecessary host-specific details and excluding all secret-bearing material.

The original reports remain the provenance source for those visual transcripts.
