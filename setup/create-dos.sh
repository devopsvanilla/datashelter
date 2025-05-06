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
prompt_env_variable "DO_SPACE_NAME" "my-space"
prompt_env_variable "DO_SPACE_REGION" "nyc3"
prompt_env_variable "DO_SPACE_ACCESS_KEY" ""
prompt_env_variable "DO_SPACE_SECRET_KEY" ""

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

# 2. Show summary and ask for confirmation
cat <<EOP

Configuration summary:
  Space name: $DO_SPACE_NAME
  Region: $DO_SPACE_REGION
  Access Key: ${DO_SPACE_ACCESS_KEY:0:4}****************
  Secret Key: ${DO_SPACE_SECRET_KEY:0:4}****************
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
DO_SPACE_NAME=$DO_SPACE_NAME
DO_SPACE_REGION=$DO_SPACE_REGION
DO_SPACE_ACCESS_KEY=$DO_SPACE_ACCESS_KEY
DO_SPACE_SECRET_KEY=$DO_SPACE_SECRET_KEY
DO_TOKEN=$DO_TOKEN
EOF

# 4. Check for doctl installation
if ! command -v doctl &> /dev/null; then
  echo "🚀 Installing doctl CLI..."
  sudo snap install doctl
fi

# 4.1. Check for AWS CLI installation
if ! command -v aws &> /dev/null; then
  echo "🚀 Installing AWS CLI (official method)..."
  TMP_DIR="$(mktemp -d)"
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMP_DIR/awscliv2.zip"
  unzip "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"
  sudo "$TMP_DIR/aws/install"
  rm -rf "$TMP_DIR"
fi

# 4.2. Check for curl
if ! command -v curl &> /dev/null; then
  echo "🚀 Installing curl..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y curl
  elif command -v yum &> /dev/null; then
    sudo yum install -y curl
  fi
fi

# 4.3. Check for unzip
if ! command -v unzip &> /dev/null; then
  echo "🚀 Installing unzip..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y unzip
  elif command -v yum &> /dev/null; then
    sudo yum install -y unzip
  fi
fi

# 4.4. Check for python3 and pip (for some awscli installs)
if ! command -v python3 &> /dev/null; then
  echo "🚀 Installing python3..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y python3
  elif command -v yum &> /dev/null; then
    sudo yum install -y python3
  fi
fi
if ! command -v pip3 &> /dev/null; then
  echo "🚀 Installing python3-pip..."
  if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y python3-pip
  elif command -v yum &> /dev/null; then
    sudo yum install -y python3-pip
  fi
fi

# 5. Check for authentication
if ! doctl auth list 2>/dev/null | grep -q "Valid"; then
  echo "🔑 DigitalOcean authentication is required."
  doctl auth init -t "$DO_TOKEN"
else
  echo "✅ doctl is already authenticated."
fi

# 6. Check if space exists
if doctl compute cdn list | grep -q "$DO_SPACE_NAME"; then
  echo "ℹ️  The space '$DO_SPACE_NAME' already exists. Skipping creation."
else
  echo "📦 Creating DigitalOcean Space: $DO_SPACE_NAME..."
  AWS_ACCESS_KEY_ID="$DO_SPACE_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$DO_SPACE_SECRET_KEY" \
    aws --endpoint-url "https://$DO_SPACE_REGION.digitaloceanspaces.com" s3 mb "s3://$DO_SPACE_NAME"
  echo "✅ Space created: $DO_SPACE_NAME in region $DO_SPACE_REGION"
fi
