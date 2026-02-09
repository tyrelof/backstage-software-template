#!/bin/bash
# Rollback script for ${{ values.app_name }}

set -e

NAMESPACE="${1:-${{ values.app_name }}}"
REVISION="${2:-0}"

echo "Rolling back ${{ values.app_name }} in namespace $NAMESPACE..."

if [ "$REVISION" = "0" ]; then
  echo "Available revisions:"
  helm history "${{ values.app_name }}" -n "$NAMESPACE"
  echo ""
  echo "Usage: rollback.sh <namespace> <revision>"
  echo "Example: rollback.sh ${{ values.app_name }} 1"
  exit 1
fi

echo "Rolling back to revision $REVISION..."
helm rollback "${{ values.app_name }}" "$REVISION" -n "$NAMESPACE"

echo "Rollback complete!"
echo ""
echo "View deployment status:"
echo "  kubectl rollout status deployment/${{ values.app_name }} -n $NAMESPACE"
