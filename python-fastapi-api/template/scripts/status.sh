#!/bin/bash
# Status and logs script for ${{ values.app_name }}

set -e

NAMESPACE="${1:-${{ values.app_name }}}"

echo "=== Deployment Status for ${{ values.app_name }} in $NAMESPACE ==="
echo ""

echo "Deployment:"
kubectl get deployment -n "$NAMESPACE" -l app=${{ values.app_name }}

echo ""
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l app=${{ values.app_name }}

echo ""
echo "Service:"
kubectl get svc -n "$NAMESPACE" -l app=${{ values.app_name }}

echo ""
echo "Ingress:"
kubectl get ingress -n "$NAMESPACE" -l app=${{ values.app_name }}

echo ""
echo "Recent Events:"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10

echo ""
echo "Resource Usage:"
kubectl top pods -n "$NAMESPACE" -l app=${{ values.app_name }} 2>/dev/null || echo "Metrics not available"
