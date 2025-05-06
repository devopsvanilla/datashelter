#!/bin/bash

ENV_FILE=".env"

# Function to prompt and export env variable
function prompt_env_variable() {
  local var_name="$1"
  local default_value="$2"
  local current_value="${!var_name}"

  if [ -z "$current_value" ]; then
    current_value="$default_value"
  fi

  read -p "Enter value for $var_name [$current_value]: " input
  if [ -n "$input" ]; then
    export "$var_name"="$input"
  else
    export "$var_name"="$current_value"
  fi
}

# Function to mask token
function mask_token() {
  local token="$1"
  if [ -n "$token" ]; then
    echo "${token:0:4}****************"
  fi
}

# 1. Load or initialize .env
if [ -f "$ENV_FILE" ]; then
  echo "🔄 Loading variables from $ENV_FILE..."
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "⚠️  .env file not found. It will be created."
fi

# 1. Prompt all variables at the start
prompt_env_variable "DO_REGISTRY_NAME" "my-registry"
prompt_env_variable "DO_REGISTRY_REGION" "nyc3"
prompt_env_variable "DO_REGISTRY_VISIBILITY" "starter"
prompt_env_variable "DOCKER_IMAGE_NAME" "datashelter-backup"

# Get current date and time for default tag
DEFAULT_TAG=$(date +%Y-%m-%d-%H%M%S)
read -p "Enter value for DOCKER_IMAGE_TAG [$DEFAULT_TAG]: " input_tag
if [ -n "$input_tag" ]; then
  DOCKER_IMAGE_TAG="$input_tag"
else
  DOCKER_IMAGE_TAG="$DEFAULT_TAG"
fi

# Prompt for DigitalOcean token
if [ -z "$DO_TOKEN" ] && grep -q '^DO_TOKEN=' "$ENV_FILE"; then
  export DO_TOKEN=$(grep '^DO_TOKEN=' "$ENV_FILE" | cut -d'=' -f2-)
fi
MASKED_TOKEN=$(mask_token "$DO_TOKEN")
read -s -p "Enter your DigitalOcean Personal Access Token [${MASKED_TOKEN}]: " INPUT_TOKEN
echo
if [ -n "$INPUT_TOKEN" ]; then
  export DO_TOKEN="$INPUT_TOKEN"
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
DOCKER_CONTEXT="$PROJECT_ROOT/images/mysql-backup-minimal"

# 2. Show summary and ask for confirmation
cat <<EOP

Configuration summary:
  Registry: $DO_REGISTRY_NAME
  Region: $DO_REGISTRY_REGION
  Visibility: $DO_REGISTRY_VISIBILITY
  Docker image: $DOCKER_IMAGE_NAME
  Tag: $DOCKER_IMAGE_TAG
  DigitalOcean Token: $(mask_token "$DO_TOKEN")

Type C to continue or any other key to cancel.
EOP
read -n 1 -r CONFIRM && echo
if [[ ! "$CONFIRM" =~ ^[Cc]$ ]]; then
  echo "❌ Execution cancelled."
  exit 1
fi

# 3. Save variables to .env
echo "💾 Saving variables to $ENV_FILE..."
cat > "$ENV_FILE" <<EOF
DO_REGISTRY_NAME=$DO_REGISTRY_NAME
DO_REGISTRY_REGION=$DO_REGISTRY_REGION
DO_REGISTRY_VISIBILITY=$DO_REGISTRY_VISIBILITY
DOCKER_IMAGE_NAME=$DOCKER_IMAGE_NAME
DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG
DO_TOKEN=$DO_TOKEN
EOF

# 4. Check for doctl installation
if ! command -v doctl &> /dev/null; then
  echo "🚀 Installing doctl CLI..."
  sudo snap install doctl
fi

# 5. Check for authentication
if ! doctl auth list 2>/dev/null | grep -q "Valid"; then
  echo "🔑 DigitalOcean authentication is required."
  doctl auth init -t "$DO_TOKEN"
else
  echo "✅ doctl is already authenticated."
fi

# 6. Check if registry exists
if doctl registry get "$DO_REGISTRY_NAME" &>/dev/null; then
  echo "ℹ️  The registry '$DO_REGISTRY_NAME' already exists. Skipping creation."
else
  echo "📦 Creating Docker registry: $DO_REGISTRY_NAME..."
  doctl registry create "$DO_REGISTRY_NAME" \
    --region "$DO_REGISTRY_REGION" \
    --subscription-tier "$DO_REGISTRY_VISIBILITY"
  echo "✅ Registry created at: registry.digitalocean.com/$DO_REGISTRY_NAME"
fi

# 7. Build Docker image
DOCKER_IMAGE_FULL="registry.digitalocean.com/$DO_REGISTRY_NAME/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG"
echo "🐳 Building Docker image: $DOCKER_IMAGE_FULL..."
docker build -t "$DOCKER_IMAGE_FULL" "$DOCKER_CONTEXT"

echo "📤 Pushing Docker image to registry..."
docker push "$DOCKER_IMAGE_FULL"
echo "✅ Docker image pushed: $DOCKER_IMAGE_FULL"
