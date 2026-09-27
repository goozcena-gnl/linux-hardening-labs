# TP2 authentication configuration excerpts

These are sanitized excerpts from the documented lab configuration.

## pwquality

```ini
minlen = 16
minclass = 4
dcredit = -2
ucredit = -2
lcredit = -2
ocredit = -2
maxrepeat = 2
maxsequence = 1
gecoscheck = 1
usercheck = 1
enforce_for_root
```

## faillock

```ini
deny = 3
fail_interval = 900
unlock_time = 900
```

## pam_time

```text
login|sshd;*;!root;Al0800-2000
```

## SSH effective intent

```text
UsePAM yes
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
DenyUsers rescue
AuthenticationMethods publickey,keyboard-interactive:pam
```

Relevant SSH PAM authentication lines:

```text
auth optional pam_exec.so /usr/local/sbin/log-ssh-attempt.sh
auth required pam_google_authenticator.so
```

## localadm sudo OTP

sudoers:

```text
Defaults:localadm pam_service=sudo-localadm
Defaults:localadm pam_login_service=sudo-localadm
localadm ALL=(ALL:ALL) ALL
```

`/etc/pam.d/sudo-localadm`:

```text
auth required pam_google_authenticator.so
account include system-auth
session include system-auth
session optional pam_systemd.so class=none
```
