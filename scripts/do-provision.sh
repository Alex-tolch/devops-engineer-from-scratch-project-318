#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DO_TOKEN:-}" ]]; then
  echo "Set DO_TOKEN env var" >&2
  exit 1
fi

export PATH="${HOME}/.local/bin:${PATH}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}/terraform"

PUBKEY="$(cat "${HOME}/.ssh/id_rsa.pub")"
KEY_ID="$(echo "${PUBKEY}" | awk '{print $2}')"

FP="$(
  curl -fsS -H "Authorization: Bearer ${DO_TOKEN}" \
    https://api.digitalocean.com/v2/account/keys |
    python3 -c "
import json, sys
kid = sys.argv[1]
for k in json.load(sys.stdin).get('ssh_keys', []):
    parts = k.get('public_key', '').split()
    if len(parts) >= 2 and parts[1] == kid:
        print(k['fingerprint'])
        break
" "${KEY_ID}"
)"

if [[ -z "${FP}" ]]; then
  PAYLOAD="$(python3 -c "import json; print(json.dumps({'name': 'hexlet-wsl', 'public_key': open('${HOME}/.ssh/id_rsa.pub').read().strip()}))")"
  FP="$(
    curl -fsS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${DO_TOKEN}" \
      -d "${PAYLOAD}" https://api.digitalocean.com/v2/account/keys |
      python3 -c "import json,sys; print(json.load(sys.stdin)['ssh_key']['fingerprint'])"
  )"
fi

BUCKET="${SPACES_BUCKET_NAME:-hexlet-b318-$(openssl rand -hex 4)}"

cat > terraform.tfvars <<EOF
do_token             = "${DO_TOKEN}"
project_name         = "hexlet-bulletins"
region               = "fra1"
ssh_key_fingerprint  = "${FP}"
spaces_bucket_name   = "${BUCKET}"
EOF
chmod 600 terraform.tfvars

terraform init -input=false
terraform apply -auto-approve -input=false
terraform output
terraform output -raw database_password
