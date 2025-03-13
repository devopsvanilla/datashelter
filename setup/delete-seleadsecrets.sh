#!/bin/bash

set -e

# Define the namespace and deployment name
NAMESPACE="kube-system"
DEPLOYMENT="sealed-secrets"

# Function to handle user confirmation
confirm_action() {
    while true; do
        echo
        read -p "$1 (y/n): " -n 1 -r
        case "$REPLY" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Function to handle script interruption
handle_interruption() {
    echo "❌  Operation canceled."
    echo "⚠️  Deployment was partially completed. Please remove remaining resources to ensure DataShelter functionality."
    exit 1
}

# Function to handle command errors
handle_error() {
    local lineno=$1
    local scriptname=$(basename "$0")
    echo "\e[31m❌  Error on line $lineno in $scriptname\e[0m"
    exit 1
}

# Trap errors and call handle_error
trap 'handle_error $LINENO' ERR

../utils/display-banner.sh

echo "🚨  WARNING: This will completely remove Sealed Secrets resource and all associated secrets!"
if ! confirm_action "Are you sure you want to continue?"; then
    handle_interruption
fi

echo
echo "🛑  Deleting Sealed Secrets deployment and related resources..."

# Delete the Sealed Secrets deployment
echo
echo "🗑️  Deleting Sealed Secrets deployment..."
kubectl delete deploy "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting Sealed Secrets service?"; then
    handle_interruption
fi

# Delete the Sealed Secrets service
echo
echo "🗑️  Deleting Sealed Secrets service..."
kubectl delete svc "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting Sealed Secrets service account?"; then
    handle_interruption
fi

# Delete the Sealed Secrets service account
echo
echo "🗑️  Deleting Sealed Secrets service account..."
kubectl delete sa sealed-secrets -n "$NAMESPACE" --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting Sealed Secrets CRDs?"; then
    handle_interruption
fi

# Delete SealedSecret CRDs
echo
echo "🗑️  Deleting Sealed Secrets CRDs..."
kubectl delete crd sealedsecrets.bitnami.com --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting all SealedSecrets?"; then
    handle_interruption
fi

# Delete all SealedSecrets from all namespaces
echo
echo "🗑️  Deleting all SealedSecrets..."
kubectl delete sealedsecret --all --all-namespaces --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting Helm release secret for Sealed Secrets?"; then
    handle_interruption
fi

# Delete Helm-related secrets
echo
echo "🗑️  Deleting Helm release secret for Sealed Secrets..."
kubectl delete secret -n "$NAMESPACE" -l owner=helm --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting Sealed Secrets keys?"; then
    handle_interruption
fi

# Delete Sealed Secrets controller keys (private & public keys)
echo
echo "🗑️  Deleting Sealed Secrets keys..."
kubectl delete secret -n "$NAMESPACE" -l sealedsecrets.bitnami.com/sealed-secrets-key --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with deleting Sealed Secrets Pod Disruption Budgets?"; then
    handle_interruption
fi

# Delete Sealed Secrets Pod Disruption Budgets
echo
echo "🗑️  Deleting Sealed Secrets Pod Disruption Budgets..."
kubectl delete pdb -n "$NAMESPACE" -l app.kubernetes.io/name=sealed-secrets --ignore-not-found || handle_interruption

# Confirm deletion
if ! confirm_action "Continue with searching for decrypted Secrets created by Sealed Secrets?"; then
    handle_interruption
fi

# Find all Secrets that were created by Sealed Secrets
echo
echo "🗑️  Searching for decrypted Secrets created by Sealed Secrets..."
SECRETS_TO_DELETE=$(kubectl get secrets --all-namespaces -o json | jq -r '[.items[] | select(.metadata.ownerReferences?[]?.kind == "SealedSecret") | .metadata.name + " -n " + .metadata.namespace] | @tsv')

# Check if there are secrets to delete
if [[ -n "$SECRETS_TO_DELETE" ]]; then
    echo
    echo "🗑️  Deleting decrypted Secrets..."
    echo "$SECRETS_TO_DELETE" | xargs -r -n 3 kubectl delete secret || handle_interruption
fi

echo
printf '%*s\n' "$(tput cols)" '' | tr ' ' '-'
echo
echo "🎉  Sealed Secrets and all related secrets have been removed."
echo "👋  Thank you for using DataShelter!"