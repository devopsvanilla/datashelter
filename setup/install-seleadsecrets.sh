#!/usr/bin/bash

set -e

# Function to handle user confirmation
confirm_action() {
    while true; do
        read -p "$1 (y/n): " -n 1 -r
        echo
        case "$REPLY" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# Function to handle script interruption
handle_interruption() {
    local lineno=$1
    echo -e "\e[31m❌ Error at line $lineno.\e[0m"
    echo "❌ Operation canceled."
    echo "⚠️ Deployment was partially completed. Please remove remaining resources to ensure DataShelter functionality."
    exit 1
}

../utils/display-banner.sh
echo "This script will install Sealed Secrets in your cluster and demonstrate how to use it to encrypt and decrypt secrets."
if ! confirm_action "Do you want to continue?"; then
    handle_interruption $LINENO
fi

echo
echo "⏳  Checking if brew is installed..."
if command -v brew >/dev/null 2>&1; then
    echo -e "\e[33m⚠️  Brew is already installed.\e[0m"
else
    echo "Installing brew..."
    ./install-brew.sh || handle_interruption $LINENO
    echo -e "\e[32m✅ Brew installed successfully.\e[0m"
fi

# region Install Sealed Secrets
echo
echo "⏳ Deploying Sealed Secrets..."
SELEADSCRETS_NAMESPACE="kube-system"
echo "- Namespace: $SELEADSCRETS_NAMESPACE"
SELEADSCRETS_DEPLOYMENT="sealed-secrets"
echo "- Deployment: $SELEADSCRETS_DEPLOYMENT"
CLUSTER_NAME=$(kubectl config current-context)
echo "- Cluster name: $CLUSTER_NAME"

if kubectl get deploy "$SELEADSCRETS_DEPLOYMENT" -n "$SELEADSCRETS_NAMESPACE" >/dev/null 2>&1; then
    echo -e "\e[33m⚠️  Sealed Secrets is already deployed.\e[0m"
else
    echo
    echo "⏳  Waiting for deployment to be ready..."

    helm repo add bitnami https://charts.bitnami.com/bitnami || handle_interruption $LINENO
    helm repo update || handle_interruption $LINENO
    helm install sealed-secrets bitnami/sealed-secrets -n kube-system --create-namespace || handle_interruption $LINENO
    echo -e "\e[32m✅  Sealed Secrets deployed!\e[0m"
fi

# Loop until the deployment is fully available
echo
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
    kubectl get deploy -w -n "$SELEADSCRETS_NAMESPACE" -l app.kubernetes.io/name=sealed-secrets,app.kubernetes.io/instance=sealed-secrets &

    WATCH_PID=$! # Capture the process ID of `kubectl get -w`
    
    # Check the status every 5 seconds
    sleep 5
    
    # Kill the watch process before re-checking
    kill "$WATCH_PID" 2>/dev/null
done

SECRET_PUBLICKEY_MANIFEST="${CLUSTER_NAME}__sealedsecrets-key.yaml"
echo
echo "⏳ Saving Sealed Secrets public key"
if kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "$SECRET_PUBLICKEY_MANIFEST"; then
  echo -e "\e[32m✅  Sealed Secrets public key saved successfully.\e[0m"
else
  echo -e "\e[31m❌  Failed to save Sealed Secrets public key.\e[0m"
  handle_interruption $LINENO
fi

echo
printf '%*s\n' "$(tput cols)" '' | tr ' ' '-'
echo "🔑 Sealed Secrets public key saved in: $SECRET_PUBLICKEY_MANIFEST"
echo "🔑 You can use this key to encrypt secrets in any cluster."
echo "⚠️ Save it to a secure location."
printf '%*s\n' "$(tput cols)" '' | tr ' ' '-'
echo -e

# endregion

# region Test Encrypt and Decrypt Secrets with Sealed Secrets

echo
echo "⏳  Checking if Kubeseal is installed..."
if command -v kubeseal >/dev/null 2>&1; then
    echo -e "\e[33m⚠️  Kubeseal is already installed.\e[0m"
else
    echo -e
    echo "⏳ Installing Kubeseal..."
    if brew install kubeseal; then
        echo -e "\e[32m🔐 Kubeseal installed successfully.\e[0m"
    else
        echo -e "\e[31m❌ Failed to install Kubeseal.\e[0m"
        handle_interruption $LINENO
    fi
fi

DATASHELTER_NAMESPACE="datashelter"
../utils/check-namespace.sh --name="$DATASHELTER_NAMESPACE" || handle_interruption $LINENO

echo
echo "⏳ Generating Test SealedSecret..."
USERNAME_ORIGINAL="yourusername"
PASSWORD_ORIGINAL="yoursecretpassword"
SECRET_MANIFEST="${CLUSTER_NAME}__test-secret.yaml"
echo "- Test Username original: $USERNAME_ORIGINAL"
echo "- Test Password original: $PASSWORD_ORIGINAL"
echo "- Test Secret manifest: $SECRET_MANIFEST"
../utils/generate-seleadsecret.sh --name=test-secret --namespace=$DATASHELTER_NAMESPACE \
                                  --key "username|$USERNAME_ORIGINAL" \
                                  --key "password|$PASSWORD_ORIGINAL" \
                                  --output="$SECRET_MANIFEST" || handle_interruption $LINENO

echo
echo "⏳ Applying Test SealedSecret..."
if kubectl apply -f "$SECRET_MANIFEST" --namespace "$DATASHELTER_NAMESPACE"; then
    echo "✅ SealedSecret applied successfully."

    # Obtém o nome do SealedSecret a partir do manifesto
    SECRET_NAME=$(kubectl get -f "$SECRET_MANIFEST" -o jsonpath="{.metadata.name}")

    echo "⏳ Aguardando o Secret '$SECRET_NAME' ser criado no namespace '$DATASHELTER_NAMESPACE'..."
    
    # Loop para aguardar a criação do Secret
    TIMEOUT=180  # Tempo máximo de espera (segundos)
    INTERVAL=5   # Intervalo entre as verificações (segundos)
    ELAPSED=0

    while [[ $ELAPSED -lt $TIMEOUT ]]; do
        if kubectl get secret "$SECRET_NAME" --namespace "$DATASHELTER_NAMESPACE" >/dev/null 2>&1; then
            echo "✅ Secret '$SECRET_NAME' está disponível no namespace '$DATASHELTER_NAMESPACE'."
            break
        fi
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo "❌ O Secret '$SECRET_NAME' não ficou disponível dentro de $TIMEOUT segundos."
        handle_interruption $LINENO
    fi
else
    echo "❌ Failed to apply SealedSecret."
    handle_interruption $LINENO
fi


echo
echo "⏳ Decrypting Test SealedSecret..."
if kubectl get secret test-secret -n $DATASHELTER_NAMESPACE; then
    echo "✅ SealedSecret decrypted successfully."

    SECRET_SELEAD=$(kubectl get secret test-secret -n $DATASHELTER_NAMESPACE -o yaml)
    USERNAME_REVEALED=$(echo "$SECRET_SELEAD" | grep 'username:' | awk '{print $2}' | base64 --decode)
    PASSWORD_REVEALED=$(echo "$SECRET_SELEAD" | grep 'password:' | awk '{print $2}' | base64 --decode)
    echo "Username revealed: $USERNAME_REVEALED"
    echo "Password revealed: $PASSWORD_REVEALED"
    
    if [ "$USERNAME_REVEALED" = "$USERNAME_ORIGINAL" ] && [ "$PASSWORD_REVEALED" = "$PASSWORD_ORIGINAL" ]; then
        echo "✅ Success in secrets compare"
    else
        echo "❌ Error in secrets compare"
        handle_interruption $LINENO
    fi
else
    echo "❌ Failed to decrypt SealedSecret."
    handle_interruption $LINENO
fi


echo 
echo "⏳ Removing test resources..."
kubectl delete secret test-secret --namespace datashelter
rm minikube__test-secret.yaml
echo "✅ Success in removing test resources"

# endregion

echo
printf '%*s\n' "$(tput cols)" '' | tr ' ' '-'
echo
echo "🎉  Sealed Secrets installed successfully!"
echo "👋  Thank you for using DataShelter!"
echo