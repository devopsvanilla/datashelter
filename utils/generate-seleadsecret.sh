#!/bin/bash

# Function to display correct script usage
usage() {
  echo "❌ Usage: $0 --name=my-secret --namespace=default --key \"key1|value1\" --key \"key2|value2\" --output=my-secret.yaml"
  exit 1
}

# Variable declarations
NAMESPACE=""
SECRET_NAME=""
declare -A KEYS

# Process input arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --key)
      shift
      PAIR="$1"
      KEY="${PAIR%%|*}"       # Extract everything before the first "|"
      VALUE="${PAIR#*|}"      # Extract everything after the first "|"
      KEYS["$KEY"]="$VALUE"
      ;;
    --namespace=*)
      NAMESPACE="${1#--namespace=}"
      ;;
    --name=*)
      SECRET_NAME="${1#--name=}"
      ;;
    --output=*)
      OUTPUT_FILE="${1#--output=}"
      ;;
    *)
      usage
      ;;
  esac
  shift
done

# Validate required parameters
if [[ -z "$NAMESPACE" || -z "$SECRET_NAME" || ${#KEYS[@]}  -eq 0 || -z "$OUTPUT_FILE" ]]; then
  usage
fi

# Initialize the SealedSecret YAML structure
SEALED_SECRET=$(cat <<EOF
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
spec:
  encryptedData:
EOF
)

# Process each key-value pair and encrypt it
for KEY in "${!KEYS[@]}"; do
  VALUE="${KEYS[$KEY]}"

  # Encrypt the value using kubeseal with the correct Sealed Secrets Controller name
  ENCRYPTED_VALUE=$(echo -n "$VALUE" | kubeseal --raw --name="$SECRET_NAME" --namespace="$NAMESPACE" --controller-name=sealed-secrets --controller-namespace=kube-system)

  # Append to the SealedSecret YAML structure
  SEALED_SECRET+=$'\n'"    $KEY: $ENCRYPTED_VALUE"
done

# Save the YAML file
echo "$SEALED_SECRET" > "$OUTPUT_FILE"

echo "✅ SealedSecret saved in: $OUTPUT_FILE"
echo "🔐 Now apply it to the cluster with:"
echo "   kubectl apply -f $OUTPUT_FILE -n $NAMESPACE"
