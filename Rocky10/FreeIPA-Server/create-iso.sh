#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
files_dir="${script_dir}/files"
image_dir="${script_dir}/image"
env_file="${files_dir}/.env"
user_data_template="${files_dir}/user-data.template"
network_config_template="${files_dir}/network-config.template"
meta_data_template="${files_dir}/meta-data.template"
rendered_user_data="${files_dir}/user-data"
rendered_network_config="${files_dir}/network-config"
rendered_meta_data="${files_dir}/meta-data"
iso_name="cinit_Rocky10_FreeIPA-Server.iso"
iso_path="${image_dir}/${iso_name}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

require_cmd envsubst
require_cmd cloud-localds

if [[ ! -f "${env_file}" ]]; then
  printf 'Missing %s. Run ./create-env.sh first.\n' "${env_file}" >&2
  exit 1
fi

if [[ ! -f "${user_data_template}" ]]; then
  printf 'Missing template file: %s\n' "${user_data_template}" >&2
  exit 1
fi

if [[ ! -f "${network_config_template}" ]]; then
  printf 'Missing template file: %s\n' "${network_config_template}" >&2
  exit 1
fi

if [[ ! -f "${meta_data_template}" ]]; then
  printf 'Missing template file: %s\n' "${meta_data_template}" >&2
  exit 1
fi

mkdir -p "${image_dir}"

set -a
source "${env_file}"
set +a

required_vars=(
  FQDN
  INTERFACE_NAME
  STATIC_IP_CIDR
  STATIC_IP
  GATEWAY_IP
  NAMESERVERS_YAML
  TIMEZONE
  ROOT_PASSWORD_HASH
  SYSADMIN_PASSWORD_HASH
  SYSADMIN_SSH_PUBKEY
  ANSIBLE_SSH_PUBKEY
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    printf 'Required variable %s is not set in %s\n' "${var_name}" "${env_file}" >&2
    exit 1
  fi
done

if [[ -z "${RPM_PROXY_URL+x}" ]]; then
  printf 'Required variable RPM_PROXY_URL is not set in %s\n' "${env_file}" >&2
  exit 1
fi

HOSTNAME_SHORT="${FQDN%%.*}"
export HOSTNAME_SHORT

if [[ "${ROOT_PASSWORD_HASH}" != \$y\$* ]]; then
  printf 'ROOT_PASSWORD_HASH must be yescrypt (start with $y$). Re-run ./create-env.sh\n' >&2
  exit 1
fi

if [[ "${SYSADMIN_PASSWORD_HASH}" != \$y\$* ]]; then
  printf 'SYSADMIN_PASSWORD_HASH must be yescrypt (start with $y$). Re-run ./create-env.sh\n' >&2
  exit 1
fi

envsubst < "${user_data_template}" > "${rendered_user_data}"
envsubst < "${network_config_template}" > "${rendered_network_config}"
envsubst < "${meta_data_template}" > "${rendered_meta_data}"
chmod 600 "${rendered_user_data}"

rm -f "${iso_path}"
cloud-localds \
  --filesystem=iso \
  --network-config="${rendered_network_config}" \
  "${iso_path}" \
  "${rendered_user_data}" \
  "${rendered_meta_data}"

printf 'Created %s\n' "${iso_path}"
