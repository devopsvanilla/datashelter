#!/bin/bash

# Function to display an error message and exit
function show_error_and_exit {
  echo "❌ Error: You must provide a namespace name using the --name parameter."
  echo "Usage: $0 --name <namespace>"
  exit 1
}

# Parse the command-line arguments to get the namespace name
for arg in "$@"; do
  case $arg in
    --name=*) NAMESPACE="${arg#*=}" ;;
    --name) shift; NAMESPACE="$1" ;;
  esac
done

# Check if the namespace name is provided
if [ -z "$NAMESPACE" ]; then
  show_error_and_exit
fi

# Check if the namespace already exists
if kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  echo "✅ The namespace '$NAMESPACE' already exists."
else
  echo "⚠️ The namespace '$NAMESPACE' does not exist. Creating it now..."
  kubectl create namespace "$NAMESPACE"
  echo "🎉 Namespace '$NAMESPACE' created successfully."
fi