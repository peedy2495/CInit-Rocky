# CInit-Rocky

Cloud-init templates and helper scripts for Rocky Linux cloud images.

The repository currently contains a Rocky 10 template for a FreeIPA server at `Rocky10/FreeIPA-Server/`. The goal is to generate a cloud-init ISO with predictable host, network, user, and SSH settings while keeping secrets out of git.

## FreeIPA Template Layout

Inside `Rocky10/FreeIPA-Server/files/`:

- `user-data.template`
  Main cloud-config template.
- `network-config.template`
  Separate network definition used with `cloud-localds --network-config`.
- `meta-data.template`
  Cloud-init metadata template.
- `.env.example`
  Example variable file showing the expected keys.
- `.env`
  Generated secret and deployment-specific values. This file is ignored by git.
- `user-data`, `network-config`, `meta-data`
  Rendered output files created during ISO generation. These files are also ignored by git.

## Structural Features

- Host and network settings are explicit.
  The template sets FQDN, hostname, static IPv4, gateway, and nameservers.
- Optional RPM proxy rewriting is supported.
  Repo files can be rewritten before package operations run.

## Security Features

- Secrets are not stored in tracked files.
  `.env`, rendered cloud-init files, and generated ISOs are ignored by git.
- Password hashes use yescrypt.
  `create-env.sh` generates `$y$` hashes with `mkpasswd`.
- SSH password authentication is disabled.
  The template writes a dedicated SSH hardening config with `PasswordAuthentication no`.
- Root SSH login is disabled.
  `PermitRootLogin no` is enforced.
- `sysadmin` and `root` have hashed local passwords.
  Both accounts are provisioned with `hashed_passwd`.
- `ansible` is key-only.
  The account is password-locked and receives only SSH authorized keys.
- `sysadmin` uses password-protected sudo.
  The template combines `sudo: ["ALL=(ALL) ALL"]` with `Defaults rootpw`.
- `ansible` keeps passwordless sudo.
  `sudo: ["ALL=(ALL) NOPASSWD:ALL"]` is configured for automation.

## Provisioned System Behavior

The FreeIPA template prepares a Rocky 10 cloud image with:

- FQDN and hostname derived from the supplied `FQDN`
- static network configuration in a separate `network-config`
- `root`, `sysadmin`, and `ansible` users
- SSH hardening with public key access for the managed users
- firewall ports for FreeIPA-related services
- `chrony`, `firewalld`, and `bind-utils`
- no automatic `ipa-server-install`

This template prepares the OS for FreeIPA deployment, but does not run the interactive FreeIPA installer itself.

## create-env.sh

Path: Rocky10/FreeIPA-Server/create-env.sh

Purpose:

- collects deployment-specific values interactively
- writes `Rocky10/FreeIPA-Server/files/.env`

It asks for:

- `FQDN`
- interface name
- static IP with CIDR
- gateway IP
- comma-separated nameservers
- timezone
- optional RPM proxy baseurl prefix
- root password
- sysadmin password
- sysadmin SSH public key
- ansible SSH public key

Important details:

- empty RPM proxy input means no repo rewrite is performed
- `HOSTNAME_SHORT` is derived from `FQDN`
- `STATIC_IP` is derived from `STATIC_IP_CIDR`
- nameservers are rendered into YAML list format for cloud-init

Run it with:

```bash
cd Rocky10/FreeIPA-Server
./create-env.sh
```

## create-iso.sh

Path: Rocky10/FreeIPA-Server/create-iso.sh

Purpose:

- reads `files/.env`
- renders `user-data`, `network-config`, and `meta-data`
- builds `image/cinit_Rocky10_FreeIPA-Server.iso`

Run it with:

```bash
cd Rocky10/FreeIPA-Server
./create-iso.sh
```

## RPM Proxy Behavior

If `RPM_PROXY_URL` is set in `.env`, `runcmd` updates every repo file in `/etc/yum.repos.d` by:

- disabling `mirrorlist=`
- enabling `baseurl=`
- replacing `http://dl.rockylinux.org/` with the supplied proxy prefix

This happens before package upgrade and installation, because package operations only work after the repo definitions are adjusted for the proxy environment.

If `RPM_PROXY_URL` is empty, repo files are left unchanged.

## Typical Workflow

```bash
cd Rocky10/FreeIPA-Server
./create-env.sh
./create-iso.sh
```

Result:

- rendered files appear in `Rocky10/FreeIPA-Server/files/`
- ISO appears in `Rocky10/FreeIPA-Server/image/cinit_Rocky10_FreeIPA-Server.iso`

## Requirements

The helper scripts expect these tools on the build host:

- `bash`
- `mkpasswd`
- `envsubst`
- `cloud-localds`

## Notes

- If you manually edit `.env`, rerun `./create-iso.sh` to regenerate the rendered cloud-init files.
- If you change passwords, rerun `./create-env.sh` so the yescrypt hashes are regenerated correctly.
