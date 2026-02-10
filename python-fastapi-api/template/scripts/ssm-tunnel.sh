#!/bin/bash
set -euo pipefail

LOCK_REGION="us-east-2"

usage() {
  echo "Usage:"
  echo "  ./ssm-tunnel.sh <instance-id|instance-name> <host> [remotePort] [localPort] [region]"
  echo
  echo "Examples:"
  echo "  ./ssm-tunnel.sh i-04017ff0b2ed2bafa mydb.xxx.us-east-2.rds.amazonaws.com 5432 5432"
  echo "  ./ssm-tunnel.sh my-bastion mydb.xxx.us-east-2.rds.amazonaws.com 3306 3306"
  echo "  ./ssm-tunnel.sh my-bastion mydb.xxx.us-east-2.rds.amazonaws.com 1433 1433 us-east-2"
}

[[ $# -ge 2 ]] || { usage; exit 1; }

INSTANCE_INPUT="$1"
HOST="$2"
REMOTE_PORT="${3:-5432}"
LOCAL_PORT="${4:-$REMOTE_PORT}"
REGION="${5:-$LOCK_REGION}"

[[ "$REGION" == "$LOCK_REGION" ]] || { echo "Error: Region locked to $LOCK_REGION (got: $REGION)"; exit 1; }

resolve_instance_id() {
  local input="$1"
  if [[ "$input" =~ ^i-[0-9a-f]{8,}$ ]]; then
    echo "$input"
    return
  fi

  local iid
  iid=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=$input" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text) || true

  [[ -n "$iid" ]] || { echo "Error: No running instance found with Name: $input in $REGION"; exit 1; }
  echo "$iid"
}

IID="$(resolve_instance_id "$INSTANCE_INPUT")"

echo "SSM Tunnel:"
echo "  Instance: $IID"
echo "  Host:     $HOST"
echo "  Remote:   $REMOTE_PORT"
echo "  Local:    $LOCAL_PORT"
echo "  Region:   $REGION"
echo

exec aws ssm start-session \
  --target "$IID" \
  --document-name "AWS-StartPortForwardingSessionToRemoteHost" \
  --parameters "{\"host\":[\"$HOST\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
  --region "$REGION"
