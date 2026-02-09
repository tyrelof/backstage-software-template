#!/bin/bash
# Deployment script for ${{ values.app_name }}

set -e

NAMESPACE="${1:-${{ values.app_name }}}"
ENVIRONMENT="${2:-staging}"
CHART_PATH="./charts/${{ values.app_name }}"

echo "Deploying ${{ values.app_name }} to $ENVIRONMENT environment..."

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install/upgrade Helm chart
if helm list -n "$NAMESPACE" | grep -q "${{ values.app_name }}"; then
  echo "Upgrading existing release..."
  helm upgrade "${{ values.app_name }}" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "values-$ENVIRONMENT.yaml"
else
  echo "Installing new release..."
  helm install "${{ values.app_name }}" "$CHART_PATH" \
    -n "$NAMESPACE" \
    -f "values-$ENVIRONMENT.yaml"
fi

echo "Deployment complete!"
echo ""
echo "View deployment status:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "View logs:"
echo "  kubectl logs -f -l app=${{ values.app_name }} -n $NAMESPACE"
