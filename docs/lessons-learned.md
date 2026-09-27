# Lessons learned

## Configuration is not runtime state

A correct-looking configuration file can be overridden, ignored or fail to load. Effective commands such as `sshd -T`, `findmnt`, `auditctl -l` and `sysctl` are essential.

## Reboot is a security test

The TP2 module-loading lock illustrates why ordering matters. Setting `kernel.modules_disabled=1` too early can prevent storage or other required modules from loading. Reboot testing verified that encrypted storage still worked after the lock became active.

## Authentication changes need recovery paths

PAM, SSH and sudo interact. A small ordering mistake can remove every normal administration path. Changes should be staged and validated from an existing privileged console before closing the fallback session.

## “No evidence” is different from “not configured”

The audit archive did not demonstrate auditd login/logout event types. That does not justify inventing a successful test. The correct result is “not demonstrated”.

## Read-only audits are more trustworthy

A collector that changes the machine while gathering evidence makes later interpretation harder. The TP2 collector intentionally observes rather than remediates.

## Encryption availability is an operational problem too

The TP1 `nofail` design allows the operating system to remain usable when the key device is missing, while `get_data.sh` provides an explicit recovery path for `/data`.

## Hardening is contextual

Parameters that are appropriate for this VM may be wrong for another workload. Security configuration should follow the actual threat model, kernel, distribution and operational dependencies.
