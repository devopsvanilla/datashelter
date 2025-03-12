#!/bin/bash

# Define the namespace and deployment name
NAMESPACE="kube-system"
DEPLOYMENT="sealed-secrets"

echo "🚨 WARNING: This will completely remove Sealed Secrets and all associated secrets!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Operation canceled."
    exit 1
fi

echo "🛑 Deleting Sealed Secrets deployment and related resources..."

# Delete the Sealed Secrets deployment
kubectl delete deploy "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found

# Delete the Sealed Secrets service
kubectl delete svc "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found

# Delete the Sealed Secrets service account
kubectl delete sa sealed-secrets -n "$NAMESPACE" --ignore-not-found

# Delete SealedSecret CRDs
kubectl delete crd sealedsecrets.bitnami.com --ignore-not-found

# Delete all SealedSecrets from all namespaces
echo "🧹 Deleting all SealedSecrets..."
kubectl delete sealedsecret --all --all-namespaces --ignore-not-found

# Delete Helm-related secrets
echo "🗑️ Deleting Helm release secret for Sealed Secrets..."
kubectl delete secret -n "$NAMESPACE" -l owner=helm --ignore-not-found

# Delete Sealed Secrets controller keys (private & public keys)
echo "🗑️ Deleting Sealed Secrets keys..."
kubectl delete secret -n "$NAMESPACE" -l sealedsecrets.bitnami.com/sealed-secrets-key --ignore-not-found

# Find all Secrets that were created by Sealed Secrets
echo "🧹 Searching for decrypted Secrets created by Sealed Secrets..."
SECRETS_TO_DELETE=$(kubectl get secrets --all-namespaces -o json | jq -r '[.items[] | select(.metadata.ownerReferences?[]?.kind == "SealedSecret") | .metadata.name + " -n " + .metadata.namespace] | @tsv')

# Check if there are secrets to delete
if [[ -z "$SECRETS_TO_DELETE" ]]; then
    echo "✅ No decrypted Secrets found."
else
    echo "🗑️ Deleting decrypted Secrets..."
    echo "$SECRETS_TO_DELETE" | xargs -r -n 3 kubectl delete secret
fi

echo "✅ Sealed Secrets and all related secrets have been removed."
