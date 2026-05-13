#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
files_dir="${script_dir}/files"
env_file="${files_dir}/.env"
template_file="${files_dir}/.env.example"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

generate_yescrypt_hash() {
  local password="$1"
  local hash=''

  require_cmd mkpasswd

  hash="$(printf '%s' "${password}" | mkpasswd --method=yescrypt --stdin 2>/dev/null | head -n1)"
  if [[ "${hash}" == \$y\$* ]]; then
    printf '%s' "${hash}"
    return 0
  fi

  printf 'Unable to generate yescrypt hash with mkpasswd.\n' >&2
  exit 1
}

prompt_secret() {
  local prompt_label="$1"
  local value

  while true; do
    read -r -s -p "${prompt_label}: " value
    printf '\n' >&2
    if [[ -n "${value}" ]]; then
      printf '%s' "${value}"
      return 0
    fi
    printf 'Value cannot be empty.\n' >&2
  done
}

prompt_secret_optional_existing() {
  local prompt_label="$1"
  local has_existing="$2"
  local value

  if [[ "${has_existing}" == "yes" ]]; then
    read -r -s -p "${prompt_label} [keep existing]: " value
    printf '\n' >&2
    printf '%s' "${value}"
    return 0
  fi

  prompt_secret "${prompt_label}"
}

prompt_pubkey() {
  local prompt_label="$1"
  local default_value="${2:-}"
  local value
  local prompt_text="${prompt_label}: "

  if [[ -n "${default_value}" ]]; then
    prompt_text="${prompt_label} [keep existing]: "
  fi

  while true; do
    read -r -p "${prompt_text}" value
    if [[ -z "${value}" && -n "${default_value}" ]]; then
      printf '\n' >&2
      printf '%s' "${default_value}"
      return 0
    fi
    if [[ "${value}" == ssh-* ]]; then
      printf '\n' >&2
      printf '%s' "${value}"
      return 0
    fi
    printf 'Please provide a valid SSH public key starting with ssh-.\n' >&2
  done
}

prompt_text() {
  local prompt_label="$1"
  local default_value="${2:-}"
  local value
  local prompt_text="${prompt_label}: "

  if [[ -n "${default_value}" ]]; then
    prompt_text="${prompt_label} [${default_value}]: "
  fi

  while true; do
    read -r -p "${prompt_text}" value
    if [[ -z "${value}" && -n "${default_value}" ]]; then
      printf '%s' "${default_value}"
      return 0
    fi
    if [[ -n "${value}" ]]; then
      printf '%s' "${value}"
      return 0
    fi
    printf 'Value cannot be empty.\n' >&2
  done
}

prompt_text_default() {
  local prompt_label="$1"
  local default_value="$2"
  local value

  read -r -p "${prompt_label} [${default_value}]: " value
  if [[ -z "${value}" ]]; then
    printf '%s' "${default_value}"
    return 0
  fi
  printf '%s' "${value}"
}

prompt_text_optional() {
  local prompt_label="$1"
  local default_value="${2:-}"
  local value
  local prompt_text="${prompt_label}: "

  if [[ -n "${default_value}" ]]; then
    prompt_text="${prompt_label} [${default_value}]: "
  fi

  read -r -p "${prompt_text}" value
  if [[ -z "${value}" ]]; then
    printf '%s' "${default_value}"
    return 0
  fi
  printf '%s' "${value}"
}

prompt_timeserver_optional() {
  local prompt_label="$1"
  local default_value="${2:-}"
  local value
  local prompt_text="${prompt_label}: "

  if [[ -n "${default_value}" ]]; then
    prompt_text="${prompt_label} [${default_value}]: "
  fi

  while true; do
    read -r -p "${prompt_text}" value
    if [[ -z "${value}" ]]; then
      printf '%s' "${default_value}"
      return 0
    fi
    if [[ -z "${value}" || "${value}" =~ ^[[:alnum:].:_-]+$ ]]; then
      printf '%s' "${value}"
      return 0
    fi
    printf 'Please provide a hostname or IP address, or leave empty for none.\n' >&2
  done
}

prompt_mac() {
  local prompt_label="$1"
  local default_value="${2:-}"
  local value
  local prompt_text="${prompt_label}: "

  if [[ -n "${default_value}" ]]; then
    prompt_text="${prompt_label} [${default_value}]: "
  fi

  while true; do
    read -r -p "${prompt_text}" value
    value="${value,,}"
    if [[ -z "${value}" && -n "${default_value}" ]]; then
      printf '%s' "${default_value}"
      return 0
    fi
    if [[ "${value}" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
      printf '%s' "${value}"
      return 0
    fi
    printf 'Please provide a valid MAC address like 52:54:00:12:34:56.\n' >&2
  done
}

trim_text() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

nameservers_yaml_to_csv() {
  local yaml="$1"
  local csv=''
  local line
  local value

  while IFS= read -r line; do
    value="${line#*- }"
    value="$(trim_text "${value}")"
    if [[ -n "${value}" && "${value}" != "${line}" ]]; then
      if [[ -n "${csv}" ]]; then
        csv+=","
      fi
      csv+="${value}"
    fi
  done <<< "${yaml}"

  printf '%s' "${csv}"
}

escape_squote() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

if [[ ! -f "${template_file}" ]]; then
  printf 'Template file not found: %s\n' "${template_file}" >&2
  exit 1
fi

if [[ -f "${env_file}" ]]; then
  set -a
  source "${env_file}"
  set +a
  printf 'Loaded existing defaults from %s.\n' "${env_file}" >&2
fi

nameservers_csv_default="$(nameservers_yaml_to_csv "${NAMESERVERS_YAML:-}")"

fqdn="$(prompt_text "FQDN (example: ipa.example.com)" "${FQDN:-}")"
interface_mac="$(prompt_mac "Interface MAC address (example: 52:54:00:12:34:56)" "${INTERFACE_MAC:-}")"
static_ip_cidr="$(prompt_text "Static IP with CIDR (example: 192.168.0.100/24)" "${STATIC_IP_CIDR:-}")"
gateway_ip="$(prompt_text "Gateway IP (example: 192.168.0.1)" "${GATEWAY_IP:-}")"
nameservers_csv="$(prompt_text "Nameservers comma separated (example: 192.168.0.1,1.1.1.1)" "${nameservers_csv_default}")"
timezone="$(prompt_text_default "Timezone" "${TIMEZONE:-Europe/Berlin}")"
timeserver="$(prompt_timeserver_optional "Timeserver address (empty for none)" "${TIMESERVER:-}")"
rpm_proxy_url="$(prompt_text_optional "RPM proxy baseurl prefix (empty for none)" "${RPM_PROXY_URL:-}")"

root_password="$(prompt_secret_optional_existing "Root password" "$([[ -n "${ROOT_PASSWORD_HASH:-}" ]] && printf yes || printf no)")"
sysadmin_password="$(prompt_secret_optional_existing "sysadmin password" "$([[ -n "${SYSADMIN_PASSWORD_HASH:-}" ]] && printf yes || printf no)")"
sysadmin_pubkey="$(prompt_pubkey "sysadmin SSH public key" "${SYSADMIN_SSH_PUBKEY:-}")"
ansible_pubkey="$(prompt_pubkey "ansible SSH public key" "${ANSIBLE_SSH_PUBKEY:-}")"

if [[ -n "${root_password}" ]]; then
  root_hash="$(generate_yescrypt_hash "${root_password}")"
else
  root_hash="${ROOT_PASSWORD_HASH:-}"
  root_password="${ROOT_PASSWORD:-}"
fi

if [[ -n "${sysadmin_password}" ]]; then
  sysadmin_hash="$(generate_yescrypt_hash "${sysadmin_password}")"
else
  sysadmin_hash="${SYSADMIN_PASSWORD_HASH:-}"
  sysadmin_password="${SYSADMIN_PASSWORD:-}"
fi

hostname_short="${fqdn%%.*}"
static_ip="${static_ip_cidr%%/*}"

nameservers_yaml=''
IFS=',' read -r -a nameservers_array <<< "${nameservers_csv}"
for ns in "${nameservers_array[@]}"; do
  ns_trimmed="$(trim_text "${ns}")"
  if [[ -n "${ns_trimmed}" ]]; then
    nameservers_yaml+="          - ${ns_trimmed}"$'\n'
  fi
done

if [[ -z "${nameservers_yaml}" ]]; then
  printf 'At least one nameserver must be provided.\n' >&2
  exit 1
fi

cat > "${env_file}" <<EOF
FQDN='$(escape_squote "${fqdn}")'
HOSTNAME_SHORT='$(escape_squote "${hostname_short}")'
INTERFACE_MAC='$(escape_squote "${interface_mac}")'
STATIC_IP_CIDR='$(escape_squote "${static_ip_cidr}")'
STATIC_IP='$(escape_squote "${static_ip}")'
GATEWAY_IP='$(escape_squote "${gateway_ip}")'
NAMESERVERS_YAML='$(escape_squote "${nameservers_yaml}")'
TIMEZONE='$(escape_squote "${timezone}")'
TIMESERVER='$(escape_squote "${timeserver}")'
RPM_PROXY_URL='$(escape_squote "${rpm_proxy_url}")'
ROOT_PASSWORD='$(escape_squote "${root_password}")'
ROOT_PASSWORD_HASH='$(escape_squote "${root_hash}")'
SYSADMIN_PASSWORD='$(escape_squote "${sysadmin_password}")'
SYSADMIN_SSH_PUBKEY='$(escape_squote "${sysadmin_pubkey}")'
SYSADMIN_PASSWORD_HASH='$(escape_squote "${sysadmin_hash}")'
ANSIBLE_SSH_PUBKEY='$(escape_squote "${ansible_pubkey}")'
EOF

chmod 600 "${env_file}"
printf 'Wrote %s with host/network/time, repo, password hashes and SSH public keys.\n' "${env_file}"
