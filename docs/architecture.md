# Architecture

## Lab environment

The lab was implemented on an Arch Linux virtual machine using UEFI boot.

TP1 used three virtual disks:

| Device role | Size | Purpose |
| --- | ---: | --- |
| System disk | 16 GiB | OS and hardened mount layout |
| DATA disk | 20 GiB | LUKS2 container and LVM-backed `/data` |
| KEY disk | 1 GiB | Simulated removable key device, `LABEL=KEY` |

The final DATA stack was:

```text
/dev/sdb1
  └─ LUKS2
      └─ /dev/mapper/data_crypt
          └─ LVM PV
              └─ vg_data
                  └─ lv_data (15 GiB)
                      └─ ext4
                          └─ /data
```

The volume group intentionally retained free space to demonstrate LVM scalability.

## System mount layout

TP1 implemented the required split system layout:

| Mount | Size | Filesystem | Security-relevant options |
| --- | ---: | --- | --- |
| `/` | 1 GiB | ext4 | normal root mount |
| `/boot` | 512 MiB | FAT32 | `nosuid,nodev,noexec` in TP1; read-only in TP2 |
| swap | 2 GiB | swap | active |
| `/var` | 4 GiB | ext4 | `nosuid,nodev,noexec` |
| `/usr` | 4 GiB | ext4 | `nodev` |
| `/home` | remainder | ext4 | `nosuid,nodev,noexec` |
| `/tmp` | dynamic | tmpfs | `nosuid,nodev,noexec` |
| `/proc` | pseudo FS | proc | `hidepid=2` |

## Authentication evolution

```text
TP1 SSH
client
  └─ keyboard-interactive PAM
       ├─ Google Authenticator TOTP
       └─ Unix password

TP2 SSH
client
  ├─ public key
  └─ keyboard-interactive PAM
       └─ Google Authenticator TOTP
```

TP2 removes password authentication from the SSH path and requires a public key before PAM OTP.

## Boot and storage dependency

When the `LABEL=KEY` device is present, systemd can use the key file to unlock `data_crypt`, activate LVM and mount `/data`.

When it is absent, `nofail` allows the OS to boot without `/data`. The recovery script remains available from the underlying root filesystem and waits for the key device before opening LUKS and mounting the logical volume.

## TP2 control plane

TP2 adds four main control groups:

1. kernel/sysctl hardening and module-loading lock;
2. PAM policy and SSH/sudo authentication changes;
3. auditd event collection;
4. restrictive permissions and permission-change tracking.

The kernel module lock is intentionally applied **after** required modules are loaded, because `kernel.modules_disabled=1` cannot be reverted until reboot.
