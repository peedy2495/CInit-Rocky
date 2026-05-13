# Rocky10 FreeIPA-Server

This template builds a cloud-init ISO for a Rocky 10 cloud image prepared for a FreeIPA server deployment.
It does not run `ipa-server-install` automatically.

## Files

- `files/meta-data.template`: cloud-init metadata template rendered with values from `files/.env`
- `files/network-config.template`: network template rendered with values from `files/.env`
- `files/user-data.template`: cloud-config template rendered with values from `files/.env`
- `create-env.sh`: interactive helper that collects host/network values, interface MAC, nameservers, timezone, optional timeserver, passwords and SSH public keys, then writes `files/.env`
- `create-iso.sh`: renders `user-data`, `network-config`, and `meta-data`, then builds `image/cinit_Rocky10_FreeIPA-Server.iso`

## Usage

1. Run `./create-env.sh`
2. Run `./create-iso.sh`

When `files/.env` already exists, `create-env.sh` uses its values as prompt defaults.
Press Enter to keep an existing value; leaving an existing password prompt empty keeps the existing password hash.

The generated ISO follows the naming convention `cinit_<OS>_<issue>.iso`.
