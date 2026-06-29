#!/usr/bin/env bash
###############################################################################
# voting_client_generate_traffic.sh
#
# Generates continuous east-west and north-south traffic for CSW / flow-log demos.
# Each cron tick (every minute):
#   - HTTP + HTTPS passes against the web tier (UI + proxied api/Votes)
#   - HTTP pass against the app tier API directly (east-west)
#
# Usage: sudo bash voting_client_generate_traffic.sh <web-host> <app-host>
#
# Use *private* hostnames or IPs inside the VPC (e.g. voting-web01.ec2.internal).
###############################################################################
set -euo pipefail

WEB_TARGET="${1:-}"
APP_TARGET="${2:-}"
INSTALL_PATH="/usr/local/bin/voting_traffic_probe.sh"
LOG_FILE="/var/log/voting_traffic_probe.log"
CRON_TAG="# VOTING_TRAFFIC_PROBE_CRON"

if [[ -z "$WEB_TARGET" || -z "$APP_TARGET" ]]; then
  echo "Usage: $0 <web-host-or-ip> <app-host-or-ip>"
  exit 1
fi

echo "[+] Installing voting traffic probe"
echo "    Web target: $WEB_TARGET"
echo "    App target: $APP_TARGET"

sudo tee "$INSTALL_PATH" > /dev/null << 'PROBEEOF'
#!/usr/bin/env bash
WEB_TARGET="$1"
APP_TARGET="$2"
LOG_FILE="/var/log/voting_traffic_probe.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $1" | tee -a "$LOG_FILE"; }

random_lunch() {
  local items=("Pizza" "Sushi" "Tacos" "Salad" "Burger" "Pasta" "Ramen" "BBQ")
  echo "${items[$RANDOM % ${#items[@]}]}-$(date +%s)"
}

run_web_pass() {
  local SCHEME="$1"
  local BASE="${SCHEME}://${WEB_TARGET}"
  local CURL_OPTS=(-s -o /dev/null -w "%{http_code}")
  if [[ "$SCHEME" == "https" ]]; then
    CURL_OPTS+=(-k)
  fi

  local ITEM
  ITEM="$(random_lunch)"

  log "[$SCHEME/web] GET /"
  local S
  S=$(curl "${CURL_OPTS[@]}" "${BASE}/" 2>/dev/null || echo "000")
  log "[$SCHEME/web]   GET / -> $S"

  log "[$SCHEME/web] GET api/Votes"
  S=$(curl "${CURL_OPTS[@]}" "${BASE}/api/Votes?c=$(date +%s)" 2>/dev/null || echo "000")
  log "[$SCHEME/web]   GET api/Votes -> $S"

  log "[$SCHEME/web] PUT api/Votes/${ITEM}"
  S=$(curl "${CURL_OPTS[@]}" -X PUT "${BASE}/api/Votes/${ITEM}" -F "item=${ITEM}" 2>/dev/null || echo "000")
  log "[$SCHEME/web]   PUT api/Votes/${ITEM} -> $S"

  S=$(curl "${CURL_OPTS[@]}" "${BASE}/api/Votes?c=$(date +%s)" 2>/dev/null || echo "000")
  log "[$SCHEME/web]   GET api/Votes (after vote) -> $S"
}

run_app_pass() {
  local BASE="http://${APP_TARGET}"
  local ITEM
  ITEM="$(random_lunch)"

  log "[http/app] GET api/Votes (direct east-west)"
  local S
  S=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/api/Votes?c=$(date +%s)" 2>/dev/null || echo "000")
  log "[http/app]   GET api/Votes -> $S"

  log "[http/app] PUT api/Votes/${ITEM}"
  S=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${BASE}/api/Votes/${ITEM}" -F "item=${ITEM}" 2>/dev/null || echo "000")
  log "[http/app]   PUT api/Votes/${ITEM} -> $S"
}

log "===== Run started (web=${WEB_TARGET}, app=${APP_TARGET}) ====="
run_web_pass "http"
run_web_pass "https"
run_app_pass
log "===== Run finished ====="
PROBEEOF

sudo chmod +x "$INSTALL_PATH"
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

echo "[+] Installing cron job (every 1 minute)"
TMPCRON=$(mktemp)
crontab -l 2>/dev/null \
  | grep -v "$CRON_TAG" \
  | grep -v "voting_traffic_probe" \
  > "$TMPCRON" || true
{
  echo "$CRON_TAG"
  echo "* * * * * $INSTALL_PATH $WEB_TARGET $APP_TARGET >> $LOG_FILE 2>&1"
} >> "$TMPCRON"
crontab "$TMPCRON"
rm -f "$TMPCRON"

echo "[+] Installation complete"
echo "[+] Script   : $INSTALL_PATH"
echo "[+] Log file : $LOG_FILE"
echo "[+] Schedule : Every 1 minute (HTTP + HTTPS web, HTTP app API)"
echo ""
echo "Monitor: tail -f $LOG_FILE"
echo "Test:    sudo $INSTALL_PATH $WEB_TARGET $APP_TARGET"

# Run once immediately
sudo "$INSTALL_PATH" "$WEB_TARGET" "$APP_TARGET"
