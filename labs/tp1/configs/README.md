# TP1 configuration notes

These examples document the relevant lab behavior without publishing secret-bearing files.

## SSH hardening

```text
PermitRootLogin no
DenyUsers rescue
UsePAM yes
KbdInteractiveAuthentication yes
PasswordAuthentication no
AuthenticationMethods keyboard-interactive:pam
```

## sudo

TP1:

```text
localadm ALL=(ALL:ALL) NOPASSWD: ALL
rescue   ALL=(ALL:ALL) ALL
Defaults logfile="/var/log/sudo.log"
```

TP2 intentionally changes the localadm sudo authentication path; see the TP2 documentation.

## crypttab

```text
data_crypt UUID=<LUKS-UUID> /data.key:LABEL=KEY nofail,keyfile-timeout=10s
```

The actual key file is never stored in Git.

## /data fstab entry

```text
/dev/mapper/vg_data-lv_data /data ext4 defaults,nofail 0 2
```
