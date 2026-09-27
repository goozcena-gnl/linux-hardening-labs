# TP1 implementation

## 1. Filesystem layout

The system disk was split into dedicated filesystems. `/boot`, `/var`, `/usr`, `/home`, `/tmp` and `/proc` received the mount restrictions required by the exercise.

Validation used `findmnt`, `swapon --show` and an `fstab` verification after boot.

## 2. Administrative accounts

Two non-root accounts were created:

- `localadm`: administrator account;
- `rescue`: recovery account, explicitly denied over SSH.

The root password was locked. Sudo commands were sent to a dedicated `/var/log/sudo.log`.

TP1 used:

```text
localadm ALL=(ALL:ALL) NOPASSWD: ALL
rescue   ALL=(ALL:ALL) ALL
Defaults logfile="/var/log/sudo.log"
```

TP2 later removed `NOPASSWD` for `localadm` and routed sudo authentication to OTP.

## 3. SSH + TOTP

The final TP1 effective intent was:

```text
PermitRootLogin no
DenyUsers rescue
UsePAM yes
KbdInteractiveAuthentication yes
PasswordAuthentication no
AuthenticationMethods keyboard-interactive:pam
```

The PAM SSH path required Google Authenticator before the Unix authentication chain.

The exercise used the current OpenSSH name `KbdInteractiveAuthentication` rather than the older `ChallengeResponseAuthentication` wording in the assignment.

## 4. Encrypted DATA storage

The DATA disk was initialized as:

```text
LUKS2 -> data_crypt -> LVM -> vg_data/lv_data -> ext4 -> /data
```

The 20 GiB DATA disk used a 15 GiB logical volume, leaving capacity available in the volume group.

## 5. KEY device

A separate ext4 device labelled `KEY` held `data.key`.

The real key file was root-owned, mode `0400`, and was added as an additional LUKS keyslot. The key itself is intentionally absent from this repository.

The lab used a `crypttab` entry equivalent to:

```text
data_crypt UUID=<LUKS-UUID> /data.key:LABEL=KEY nofail,keyfile-timeout=10s
```

and an `fstab` entry:

```text
/dev/mapper/vg_data-lv_data /data ext4 defaults,nofail 0 2
```

## 6. Degraded boot and recovery

With the KEY device removed, the OS still booted and `/data` remained unavailable. The recovery script then:

1. waits for `LABEL=KEY`;
2. mounts the key device read-only;
3. opens LUKS with `data.key`;
4. activates `vg_data`;
5. mounts `lv_data` on `/data`.

The versioned script is [get_data.sh](../../labs/tp1/scripts/get_data.sh).

## 7. GRUB

The GRUB configuration directory was restricted to root and authenticated editing of boot entries was tested. The repository documents the behavior but does not publish password hashes.
