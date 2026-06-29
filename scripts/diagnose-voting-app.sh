#!/usr/bin/env bash
# Quick health check for all voting-app tiers. Run from repo root after deploy.
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
cd "$TF_DIR"

WEB_IP="$(terraform output -raw voting_web_public_ip 2>/dev/null || true)"
APP_IP="$(terraform output -raw voting_app_public_ip 2>/dev/null || true)"
DB_IP="$(terraform output -raw voting_db_private_ip 2>/dev/null || true)"
CLIENT_IP="$(terraform output -raw traffic_client_private_ip 2>/dev/null || true)"
KEY="${TF_DIR}/voting-app-key"

if [[ -z "$WEB_IP" ]]; then
  echo "ERROR: Run terraform apply first."
  exit 1
fi

ssh_cmd() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$KEY" "$@"
}

ssh_jump() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$KEY" \
    -o ProxyCommand="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY -W %h:%p ubuntu@$WEB_IP" \
    "$@"
}

echo "=== Public endpoints ==="
curl -s -o /dev/null -w "GET http://${WEB_IP}/              -> %{http_code}\n" "http://${WEB_IP}/"
curl -s -o /dev/null -w "GET http://${WEB_IP}/api/Votes      -> %{http_code}\n" "http://${WEB_IP}/api/Votes"
curl -s -o /dev/null -w "PUT http://${WEB_IP}/api/Votes/Test -> %{http_code}\n" -X PUT "http://${WEB_IP}/api/Votes/DiagTest" -F "item=DiagTest"

echo ""
echo "=== App tier (SSH) ==="
ssh_cmd "ubuntu@${APP_IP}" 'systemctl is-active votingdata apache2; curl -s -o /dev/null -w "localhost:5001 api/Votes -> %{http_code}\n" http://127.0.0.1:5001/api/Votes; sudo journalctl -u votingdata -n 3 --no-pager' 2>/dev/null || echo "SSH to app failed"

echo ""
echo "=== DB tier (jump via web) ==="
if [[ -n "$DB_IP" ]]; then
  ssh_jump "ubuntu@${DB_IP}" 'sudo docker ps --filter name=sqlserver; nc -zv localhost 1433 2>&1 | tail -1' 2>/dev/null || echo "SSH to db failed"
else
  echo "No DB IP in outputs"
fi

echo ""
echo "=== Traffic generator (jump) ==="
if [[ -n "$CLIENT_IP" ]]; then
  ssh_jump "ubuntu@${CLIENT_IP}" 'sudo tail -5 /var/log/voting_traffic_probe.log 2>/dev/null || echo no probe log yet' 2>/dev/null || echo "SSH to client failed"
fi

echo ""
echo "See docs/API-ERRORS.md if any check is not 200."
