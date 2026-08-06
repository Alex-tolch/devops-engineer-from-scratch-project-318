#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANSIBLE_DIR="${ROOT}/ansible"
INV="${ANSIBLE_DIR}/inventory.ini"
PASS_FILE="${ANSIBLE_VAULT_PASSWORD_FILE:-/tmp/hexlet-ansible-vault-pass}"

if [[ ! -f "$INV" ]]; then
  echo "Missing $INV (copy from inventory.ini.example)" >&2
  exit 1
fi
if [[ ! -f "$PASS_FILE" ]] && [[ -f "${ANSIBLE_DIR}/.vault-password" ]]; then
  cp "${ANSIBLE_DIR}/.vault-password" "$PASS_FILE"
  chmod 644 "$PASS_FILE"
fi

cd "$ANSIBLE_DIR"
ANSIBLE_VAULT_PASSWORD_FILE="$PASS_FILE" ansible all -i inventory.ini -m ping
