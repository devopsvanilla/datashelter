#!/usr/bin/bash

echo "This script will install Sealed Secrets in your cluster and demonstrate how to use it to encrypt and decrypt secrets."
wait

echo "Installing brew if you don't have it..."
./install-brew.sh
wait

# region Install Sealed Secrets
echo "Deploying Sealed Secrets..."
SELEADSCRETS_NAMESPACE="kube-system"
echo "Namespace: $SELEADSCRETS_NAMESPACE"
SELEADSCRETS_DEPLOYMENT="sealed-secrets"
echo "Deployment: $SELEADSCRETS_DEPLOYMENT"
CLUSTER_NAME=$(kubectl config current-context)
echo "Cluster name: $CLUSTER_NAME"
wait 

echo "⏳ Waiting for deployment to be ready..."

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install sealed-secrets bitnami/sealed-secrets -n kube-system --create-namespace
echo "✅ Sealed Secrets deployed!"
wait

# Loop until the deployment is fully available
echo "⏳ Waiting for Sealed Secrets to be ready..."
while true; do
    # Get the deployment status
    STATUS=$(kubectl get deploy "$SELEADSCRETS_DEPLOYMENT" -n "$SELEADSCRETS_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

    # Check if the deployment is available
    if [[ "$STATUS" == "True" ]]; then
        echo "✅ Sealed Secrets is ready!"
        break
    fi

    # Watch for changes in real-time
    kubectl get deploy -w -n "$NAMESPACE" -l app.kubernetes.io/name=sealed-secrets,app.kubernetes.io/instance=sealed-secrets &

    WATCH_PID=$! # Capture the process ID of `kubectl get -w`
    
    # Check the status every 5 seconds
    sleep 5
    
    # Kill the watch process before re-checking
    kill "$WATCH_PID" 2>/dev/null
done

SECRET_PUBLICKEY_MANIFEST="${CLUSTER_NAME}__sealedsecrets-key.yaml"
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "$SECRET_PUBLICKEY_MANIFEST"

echo "🔑 Sealed Secrets public key saved in: $SECRET_PUBLICKEY_MANIFEST"
echo "🔑 You can use this key to encrypt secrets in any cluster."
echo "🔑 Save it to a secure location."
wait
# endregion

# region Test Encrypt and Decrypt Secrets with Sealed Secrets

if command -v kubeseal >/dev/null 2>&1; then
  if brew install kubeseal; then
    echo "🔐 Kubeseal installed successfully."
  else
    echo "❌ Failed to install Kubeseal."
    exit 1
  fi
fi

DATASHELTER_NAMESPACE="datashelter"
echo "Creating namespace $DATASHELTER_NAMESPACE..."
../utils/check-namespace.sh --name="$DATASHELTER_NAMESPACE"

echo "Generating Test SealedSecret..."
USERNAME_ORIGINAL="yourusername"
PASSWORD_ORIGINAL="yoursecretpassword"
echo "Test Username original: $USERNAME_ORIGINAL"
echo "Test Password original: $PASSWORD_ORIGINAL"
../utils/generate-seleadsecret.sh --name=test-secret --namespace=$DATASHELTER_NAMESPACE \
                                  --key "username|$USERNAME_ORIGINAL" \
                                  --key "password|$PASSWORD_ORIGINAL"

echo "Applying Test SealedSecret..."
SECRET_MANIFEST="${CLUSTER_NAME}__test-secret.yaml"
wait
if kubectl apply -f "$SECRET_MANIFEST" --namespace $DATASHELTER_NAMESPACE;then
    echo "✅ SealedSecret applied successfully."
else
    echo "❌ Failed to apply SealedSecret."
    exit 1
fi

echo "Decrypting Test SealedSecret..."
if kubectl get secret test-secret -n datashelter; then
    echo "✅ SealedSecret decrypted successfully."

    SECRET_SELEAD=$(kubectl get secret my-secret -n default -o yaml)
    USERNAME_REVEALED=$(grep 'username:' "$SECRET_SELEAD" | awk '{print $2}')
    PASSWORD_REVEALED=$(grep 'password:' "$SECRET_SELEAD" | awk '{print $2}')
    echo "Username revealed: $USERNAME_REVEALED" | base64 --decode
    echo "Password revealed: $PASSWORD_REVEALED" | base64 --decode
    # Comparação entre as variáveis
    if [ "$USERNAME_REVEALED" = "$USERNAME_ORIGINAL" ] && [ "$PASSWORD_REVEALED" = "$PASSWORD_ORIGINAL" ]; then
        echo "Sucess in secrets compare"
    else
        echo "Error in secrets compare"
    fi
else
    echo "❌ Failed to decrypt SealedSecret."
    exit 1
fi

#endregion
