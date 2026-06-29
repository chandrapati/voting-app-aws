#!/usr/bin/env bash
# verify-flow-logs.sh — VPC flow log checks for voting-app-aws (S3 + CSW readiness)
set -euo pipefail

JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "$SCRIPT_DIR/../terraform" && pwd)"
cd "$TF_DIR"

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [[ -z "$REGION" ]] && command -v terraform >/dev/null 2>&1 && [[ -f terraform.tfstate ]]; then
  REGION="$(terraform output -raw vpc_region 2>/dev/null || true)"
fi
REGION="${REGION:-us-east-1}"

BUCKET=""
if command -v terraform >/dev/null 2>&1 && [[ -f terraform.tfstate ]]; then
  BUCKET="$(terraform output -raw vpc_flow_logs_s3_bucket 2>/dev/null || true)"
fi
BUCKET="${FLOW_LOGS_BUCKET:-$BUCKET}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo unknown)"

RESULTS=()
add_result() { RESULTS+=("$1|$2|$3"); }

FLOW_TABLE=""
if command -v aws >/dev/null 2>&1; then
  FLOW_TABLE="$(aws ec2 describe-flow-logs \
    --region "$REGION" \
    --filter "Name=log-destination-type,Values=s3" \
    --query 'FlowLogs[?contains(LogDestination, `voting-app-vpc-flow-logs`) || contains(LogDestination, `voting-app`)].[FlowLogId,FlowLogStatus,LogDestination]' \
    --output text 2>/dev/null || true)"
fi

if [[ -z "$FLOW_TABLE" ]]; then
  add_result "ec2_flow_log" "warn" "No voting-app S3 flow log found (wrong region/account or flow logs disabled)"
else
  while IFS=$'\t' read -r fid status dest; do
    if [[ "$status" == "ACTIVE" ]]; then
      add_result "ec2_flow_log" "pass" "FlowLogId=$fid status=ACTIVE dest=$dest"
    else
      add_result "ec2_flow_log" "fail" "FlowLogId=$fid status=$status dest=$dest"
    fi
  done <<< "$FLOW_TABLE"
fi

S3_COUNT=0
SAMPLE_KEY=""
S3_PREFIX="AWSLogs/"
if [[ -n "$BUCKET" ]] && command -v aws >/dev/null 2>&1; then
  if aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null; then
    S3_COUNT="$(aws s3 ls "s3://${BUCKET}/${S3_PREFIX}" --recursive 2>/dev/null | wc -l | tr -d ' ')"
    SAMPLE_KEY="$(aws s3 ls "s3://${BUCKET}/${S3_PREFIX}" --recursive 2>/dev/null | tail -1 | awk '{print $4}' || true)"
    if [[ "${S3_COUNT:-0}" -gt 0 ]]; then
      add_result "s3_objects" "pass" "bucket=$BUCKET count=$S3_COUNT"
    else
      add_result "s3_objects" "fail" "bucket=$BUCKET exists but empty under ${S3_PREFIX} (wait 10-15m after traffic)"
    fi
  else
    add_result "s3_bucket" "fail" "bucket=$BUCKET not found or no access"
  fi
else
  add_result "s3_bucket" "warn" "Set FLOW_LOGS_BUCKET or run from terraform/ with state"
fi

if [[ -n "$SAMPLE_KEY" ]]; then
  HEADER="$(aws s3 cp "s3://${BUCKET}/${SAMPLE_KEY}" - 2>/dev/null | gunzip 2>/dev/null | head -1 || true)"
  if echo "$HEADER" | grep -q "pkt-srcaddr" && echo "$HEADER" | grep -q "pkt-dstaddr" && echo "$HEADER" | grep -q "version"; then
    add_result "log_format" "pass" "CSW-required fields present in sample"
  elif [[ -n "$HEADER" ]]; then
    add_result "log_format" "fail" "Missing version or pkt-* fields — git pull && terraform apply"
  else
    add_result "log_format" "warn" "Could not read sample object"
  fi
fi

export VERIFY_RESULTS="$(printf '%s\n' "${RESULTS[@]}")"
export VERIFY_REGION="$REGION"
export VERIFY_ACCOUNT="$ACCOUNT_ID"
export VERIFY_BUCKET="$BUCKET"
export VERIFY_S3_COUNT="${S3_COUNT:-0}"

if [[ "$JSON" -eq 1 ]]; then
  python3 - <<'PY'
import json, os
results = []
for line in os.environ.get("VERIFY_RESULTS", "").splitlines():
    if not line.strip():
        continue
    check, status, detail = line.split("|", 2)
    results.append({"check": check, "status": status, "detail": detail})
print(json.dumps({
    "region": os.environ.get("VERIFY_REGION", ""),
    "account_id": os.environ.get("VERIFY_ACCOUNT", ""),
    "bucket": os.environ.get("VERIFY_BUCKET", ""),
    "s3_object_count": int(os.environ.get("VERIFY_S3_COUNT", "0") or 0),
    "results": results,
}, indent=2))
PY
  exit 0
fi

echo "======================================================"
echo " Voting App VPC Flow Logs — Diagnostic"
echo " Region:  $REGION"
echo " Account: $ACCOUNT_ID"
echo " Bucket:  ${BUCKET:-<unknown>}"
echo "======================================================"
echo ""
for line in "${RESULTS[@]}"; do
  IFS='|' read -r check status detail <<< "$line"
  printf " %-14s %-6s %s\n" "[$check]" "$status" "$detail"
done
echo ""
echo "--- CSW connector (if S3 shows pass) ---"
echo "1. Manage > Workloads > Connectors > AWS"
echo "2. Select voting-app VPC; enable Flow Log Ingestion"
echo "3. Bucket: ${BUCKET:-terraform output -raw vpc_flow_logs_s3_bucket}"
echo "4. Investigate > Traffic — filter 192.168.0.0/16 after 10-15 min"
echo "======================================================"
