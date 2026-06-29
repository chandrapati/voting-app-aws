#!/usr/bin/env bash
# Smoke-test the voting app after Terraform deploy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform not found in PATH" >&2
  exit 1
fi

cd "${TF_DIR}"

WEB_IP="$(terraform output -raw voting_web_public_ip 2>/dev/null || true)"
HTTP_URL="$(terraform output -raw voting_web_url_http 2>/dev/null || true)"

if [[ -z "${WEB_IP}" ]]; then
  echo "ERROR: No terraform outputs. Run 'terraform apply' in ${TF_DIR} first." >&2
  exit 1
fi

MAX_WAIT="${MAX_WAIT:-900}" # 15 minutes (bootstrap ~8-12 min after terraform apply)
INTERVAL=30
elapsed=0

echo "==> Waiting for voting web tier at ${HTTP_URL} (up to ${MAX_WAIT}s)..."

while (( elapsed < MAX_WAIT )); do
  code="$(curl -s -o /tmp/voting-body.html -w '%{http_code}' --connect-timeout 10 "${HTTP_URL}" || echo "000")"
  if [[ "${code}" =~ ^(200|301|302)$ ]]; then
    echo "OK: HTTP ${code} from ${HTTP_URL}"
    if grep -qi "vote\|voting\|candidate" /tmp/voting-body.html 2>/dev/null; then
      echo "OK: Page content looks like the voting UI"
    else
      echo "WARN: Got HTTP ${code} but page may still be starting — open ${HTTP_URL} in a browser"
    fi
    exit 0
  fi
  echo "  ... not ready yet (HTTP ${code}), retrying in ${INTERVAL}s"
  sleep "${INTERVAL}"
  elapsed=$((elapsed + INTERVAL))
done

echo "FAIL: Voting app did not respond with HTTP 200 within ${MAX_WAIT}s" >&2
echo "Troubleshooting:" >&2
echo "  1. SSH: $(terraform output -raw ssh_web 2>/dev/null || echo 'terraform output ssh_web')" >&2
echo "  2. Check bootstrap: sudo tail -100 /var/log/cloud-init-output.log" >&2
echo "  3. Check service: sudo systemctl status votingweb apache2" >&2
exit 1
