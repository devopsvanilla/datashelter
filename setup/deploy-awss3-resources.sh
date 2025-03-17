#!/bin/bash

set -e

clear
../utils/display-banner.sh

# Colors for better readability using tput for better compatibility
if [ -t 1 ]; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 6)
  BOLD=$(tput bold)
  NC=$(tput sgr0)      # No Color/Reset
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NC=""
fi

# Function to prompt for yes/no confirmation
confirm() {
    local prompt="$1"
    local answer
    
    while true; do
        read -p "${prompt} (yes/no): " answer
        case "${answer,,}" in
            yes|y ) return 0 ;;
            no|n ) return 1 ;;
            * ) echo "Please answer 'yes' or 'no'" ;;
        esac
    done
}

# Function to display an introduction message and request confirmation
display_intro_message() {
    cat << EOF

${BLUE}📋 SCRIPT SUMMARY${NC}
    This script deploys a secure S3 bucket with associated IAM resources for data storage.
    It creates:
    • An S3 bucket with encryption, versioning, and lifecycle policies
    • IAM user with limited access permissions to the bucket
    • Security policies to enforce encryption and HTTPS

EOF
}

# Display introduction and request confirmation
display_intro_message
if ! confirm "Do you want to proceed with the AWS S3 resources deployment?"; then
    echo -e "${YELLOW}Deployment canceled by user.${NC}"
    exit 0
fi

# Default values
STACK_NAME=""
BUCKET_NAME=""
IAM_USER=""
ENVIRONMENT="Development"
DATA_CLASSIFICATION="Confidential"
OWNER=""
APPLICATION=""
TRANSITION_TO_IA_DAYS=90
TRANSITION_TO_GLACIER_DAYS=180
DAILY_BACKUP_RETENTION_DAYS=30
WEEKLY_BACKUP_RETENTION_DAYS=90
MONTHLY_BACKUP_RETENTION_DAYS=365
TEMPLATE_FILE="$(dirname "$0")/create-awss3-resources.yaml"
REGION=$(aws configure get region || echo "us-east-1")

# Script description
script_description() {
    cat << EOF

${BLUE}📄 SCRIPT DESCRIPTION${NC}
    This script deploys a CloudFormation stack that creates a secure S3 bucket 
    and associated IAM resources for secure data storage with lifecycle policies.

${BLUE}🏗️  RESOURCES TO BE DEPLOYED${NC}
    • S3 Bucket with:
      - Versioning enabled
      - Server-side encryption
      - Public access blocking
      - Lifecycle policies for object transitions and expirations
      - Custom tagging
    • S3 Bucket Policy with:
      - Encryption enforcement
      - HTTPS enforcement
    • IAM User with:
      - Password policy
      - Access key and secret key
    • IAM User Policy with:
      - Limited S3 bucket access permissions
      - Prevention of object deletion
      - Prevention of object downloading

EOF
}

# Function to display usage information
usage() {
    echo -e "${BLUE}ℹ️ USAGE${NC}"
    echo "    $0 [OPTIONS]"
    echo ""
    echo -e "${BLUE}ℹ️ REQUIRED OPTIONS${NC}"
    echo "    --stack-name=STACK_NAME        Name of the CloudFormation stack"
    echo "    --bucket-name=BUCKET_NAME      Name for the S3 bucket"
    echo "    --iam-user=IAM_USER            Name for the IAM user"
    echo "    --owner=OWNER                  Owner name for resource tagging"
    echo "    --application=APP              Application name for resource tagging"
    echo ""
    echo -e "${BLUE}ℹ️ OPTIONAL OPTIONS${NC}"
    echo "    --environment=ENV              Environment (Development|Staging|Production)"
    echo "    --data-classification=CLASS    Data classification (Public|Internal|Confidential|Restricted)"
    echo "    --transition-to-ia=DAYS        Days after which objects transition to IA (default: 90)"
    echo "    --transition-to-glacier=DAYS   Days after which objects transition to Glacier (default: 180)"
    echo "    --daily-retention=DAYS         Days to retain daily backups (default: 30)"
    echo "    --weekly-retention=DAYS        Days to retain weekly backups (default: 90)"
    echo "    --monthly-retention=DAYS       Days to retain monthly backups (default: 365)"
    echo "    --region=REGION                AWS region to deploy to (default: from AWS CLI config)"
    echo "    --help                         Display this help message"
    exit 1
}

# Function to display error messages
error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    exit 1
}

# Function to display warning messages
warning() {
    echo -e "${YELLOW}⚠️ WARNING: $1${NC}" >&2
}

# Function to display information messages
info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

# Function to validate bucket name
validate_bucket_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9][a-z0-9\.\-]{1,61}[a-z0-9]$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate IAM username
validate_iam_user() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9+=,.@_-]{1,64}$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate environment
validate_environment() {
    local env="$1"
    if [[ ! "$env" =~ ^(Development|Staging|Production)$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate data classification
validate_data_classification() {
    local class="$1"
    if [[ ! "$class" =~ ^(Public|Internal|Confidential|Restricted)$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate numeric values
validate_numeric() {
    local value="$1"
    local min="$2"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [ "$value" -lt "$min" ]; then
        return 1
    fi
    
    return 0
}

# Function to prompt for parameters interactively
prompt_for_parameters() {
    info "Interactive parameter collection mode"
    
    # Stack Name
    while [ -z "$STACK_NAME" ]; do
        read -p "Enter CloudFormation stack name: " STACK_NAME
        if [ -z "$STACK_NAME" ]; then
            warning "Stack name cannot be empty"
        fi
    done
    
    # Bucket Name
    while true; do
        read -p "Enter S3 bucket name: " BUCKET_NAME
        if validate_bucket_name "$BUCKET_NAME"; then
            break
        else
            warning "Invalid bucket name. Must be 3-63 chars, lowercase, numbers, dots, dashes, start/end with letter/number"
        fi
    done
    
    # IAM User
    while true; do
        read -p "Enter IAM username: " IAM_USER
        if validate_iam_user "$IAM_USER"; then
            break
        else
            warning "Invalid IAM username. Must be 1-64 chars with alphanumeric and these special chars: +=,.@-"
        fi
    done
    
    # Owner
    while [ -z "$OWNER" ]; do
        read -p "Enter owner name for resource tagging: " OWNER
        if [ -z "$OWNER" ]; then
            warning "Owner name cannot be empty"
        fi
    done
    
    # Application
    while [ -z "$APPLICATION" ]; do
        read -p "Enter application name for resource tagging: " APPLICATION
        if [ -z "$APPLICATION" ]; then
            warning "Application name cannot be empty"
        fi
    done
    
    # Environment
    local env_options=("Development" "Staging" "Production")
    PS3="Select environment (1-3): "
    select env_choice in "${env_options[@]}"; do
        if [ -n "$env_choice" ]; then
            ENVIRONMENT="$env_choice"
            break
        else
            warning "Invalid selection"
        fi
    done
    
    # Data Classification
    local class_options=("Public" "Internal" "Confidential" "Restricted")
    PS3="Select data classification (1-4): "
    select class_choice in "${class_options[@]}"; do
        if [ -n "$class_choice" ]; then
            DATA_CLASSIFICATION="$class_choice"
            break
        else
            warning "Invalid selection"
        fi
    done
    
    # Numeric parameters
    while true; do
        read -p "Days before transition to IA storage class [$TRANSITION_TO_IA_DAYS]: " input
        input=${input:-$TRANSITION_TO_IA_DAYS}
        if validate_numeric "$input" 30; then
            TRANSITION_TO_IA_DAYS=$input
            break
        else
            warning "Invalid value. Must be a number ≥ 30"
        fi
    done
    
    while true; do
        read -p "Days before transition to Glacier storage class [$TRANSITION_TO_GLACIER_DAYS]: " input
        input=${input:-$TRANSITION_TO_GLACIER_DAYS}
        if validate_numeric "$input" 90; then
            TRANSITION_TO_GLACIER_DAYS=$input
            break
        else
            warning "Invalid value. Must be a number ≥ 90"
        fi
    done
    
    while true; do
        read -p "Days to retain daily backups [$DAILY_BACKUP_RETENTION_DAYS]: " input
        input=${input:-$DAILY_BACKUP_RETENTION_DAYS}
        if validate_numeric "$input" 1; then
            DAILY_BACKUP_RETENTION_DAYS=$input
            break
        else
            warning "Invalid value. Must be a number ≥ 1"
        fi
    done
    
    while true; do
        read -p "Days to retain weekly backups [$WEEKLY_BACKUP_RETENTION_DAYS]: " input
        input=${input:-$WEEKLY_BACKUP_RETENTION_DAYS}
        if validate_numeric "$input" 7; then
            WEEKLY_BACKUP_RETENTION_DAYS=$input
            break
        else
            warning "Invalid value. Must be a number ≥ 7"
        fi
    done
    
    while true; do
        read -p "Days to retain monthly backups [$MONTHLY_BACKUP_RETENTION_DAYS]: " input
        input=${input:-$MONTHLY_BACKUP_RETENTION_DAYS}
        if validate_numeric "$input" 30; then
            MONTHLY_BACKUP_RETENTION_DAYS=$input
            break
        else
            warning "Invalid value. Must be a number ≥ 30"
        fi
    done
    
    # Region
    read -p "Enter AWS region [$REGION]: " input
    REGION=${input:-$REGION}
}

# Function to display the parameter summary
display_parameter_summary() {
    cat << EOF

${BLUE}📋 DEPLOYMENT PARAMETER SUMMARY${NC}
    Stack Name:                 ${STACK_NAME}
    S3 Bucket Name:             ${BUCKET_NAME}
    IAM User Name:              ${IAM_USER}
    Owner:                      ${OWNER}
    Application:                ${APPLICATION}
    Environment:                ${ENVIRONMENT}
    Data Classification:        ${DATA_CLASSIFICATION}
    Region:                     ${REGION}
    
${BLUE}📅 LIFECYCLE PARAMETERS${NC}
    Transition to IA:           ${TRANSITION_TO_IA_DAYS} days
    Transition to Glacier:      ${TRANSITION_TO_GLACIER_DAYS} days
    Daily Backup Retention:     ${DAILY_BACKUP_RETENTION_DAYS} days
    Weekly Backup Retention:    ${WEEKLY_BACKUP_RETENTION_DAYS} days
    Monthly Backup Retention:   ${MONTHLY_BACKUP_RETENTION_DAYS} days

EOF
}

# Display the script description
script_description

# Parse named parameters
for i in "$@"; do
    case $i in
        --stack-name=*)
            STACK_NAME="${i#*=}"
            shift
            ;;
        --bucket-name=*)
            BUCKET_NAME="${i#*=}"
            shift
            ;;
        --iam-user=*)
            IAM_USER="${i#*=}"
            shift
            ;;
        --environment=*)
            ENVIRONMENT="${i#*=}"
            shift
            ;;
        --data-classification=*)
            DATA_CLASSIFICATION="${i#*=}"
            shift
            ;;
        --owner=*)
            OWNER="${i#*=}"
            shift
            ;;
        --application=*)
            APPLICATION="${i#*=}"
            shift
            ;;
        --transition-to-ia=*)
            TRANSITION_TO_IA_DAYS="${i#*=}"
            shift
            ;;
        --transition-to-glacier=*)
            TRANSITION_TO_GLACIER_DAYS="${i#*=}"
            shift
            ;;
        --daily-retention=*)
            DAILY_BACKUP_RETENTION_DAYS="${i#*=}"
            shift
            ;;
        --weekly-retention=*)
            WEEKLY_BACKUP_RETENTION_DAYS="${i#*=}"
            shift
            ;;
        --monthly-retention=*)
            MONTHLY_BACKUP_RETENTION_DAYS="${i#*=}"
            shift
            ;;
        --region=*)
            REGION="${i#*=}"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            error "Unknown option: $i"
            ;;
    esac
done

# Check if any required parameters are missing
required_missing=false
if [ -z "$STACK_NAME" ] || [ -z "$BUCKET_NAME" ] || [ -z "$IAM_USER" ] || [ -z "$OWNER" ] || [ -z "$APPLICATION" ]; then
    required_missing=true
fi

# If any required parameters are missing, ask if the user wants to continue
if [ "$required_missing" = true ]; then
    if confirm "No parameters provided or some required parameters are missing. Would you like to provide them interactively?"; then
        prompt_for_parameters
    else
        error "Deployment canceled. Required parameters are missing."
    fi
fi

# Validate parameters
if ! validate_bucket_name "$BUCKET_NAME"; then
    error "Invalid bucket name: $BUCKET_NAME. Must be 3-63 chars, lowercase, numbers, dots, dashes, start/end with letter/number."
fi

if ! validate_iam_user "$IAM_USER"; then
    error "Invalid IAM username: $IAM_USER. Must be 1-64 chars with alphanumeric and these special chars: +=,.@-"
fi

if ! validate_environment "$ENVIRONMENT"; then
    error "Invalid environment: $ENVIRONMENT. Must be one of: Development, Staging, Production"
fi

if ! validate_data_classification "$DATA_CLASSIFICATION"; then
    error "Invalid data classification: $DATA_CLASSIFICATION. Must be one of: Public, Internal, Confidential, Restricted"
fi

if ! validate_numeric "$TRANSITION_TO_IA_DAYS" 30; then
    error "Invalid transition to IA days: $TRANSITION_TO_IA_DAYS. Must be ≥ 30"
fi

if ! validate_numeric "$TRANSITION_TO_GLACIER_DAYS" 90; then
    error "Invalid transition to Glacier days: $TRANSITION_TO_GLACIER_DAYS. Must be ≥ 90"
fi

if ! validate_numeric "$DAILY_BACKUP_RETENTION_DAYS" 1; then
    error "Invalid daily backup retention days: $DAILY_BACKUP_RETENTION_DAYS. Must be ≥ 1"
fi

if ! validate_numeric "$WEEKLY_BACKUP_RETENTION_DAYS" 7; then
    error "Invalid weekly backup retention days: $WEEKLY_BACKUP_RETENTION_DAYS. Must be ≥ 7"
fi

if ! validate_numeric "$MONTHLY_BACKUP_RETENTION_DAYS" 30; then
    error "Invalid monthly backup retention days: $MONTHLY_BACKUP_RETENTION_DAYS. Must be ≥ 30"
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    error "Template file not found: $TEMPLATE_FILE"
fi

# Display parameter summary
display_parameter_summary

# Confirm deployment
if ! confirm "Do you want to proceed with the deployment?"; then
    info "Deployment canceled by user."
    exit 0
fi

# Deploy the CloudFormation stack
info "Deploying CloudFormation stack '$STACK_NAME' in region '$REGION'..."
info "Using template: $TEMPLATE_FILE"

# Deploy CloudFormation stack
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters \
        ParameterKey=BucketName,ParameterValue="$BUCKET_NAME" \
        ParameterKey=IamUser,ParameterValue="$IAM_USER" \
        ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
        ParameterKey=DataClassification,ParameterValue="$DATA_CLASSIFICATION" \
        ParameterKey=Owner,ParameterValue="$OWNER" \
        ParameterKey=Application,ParameterValue="$APPLICATION" \
        ParameterKey=TransitionToIADays,ParameterValue="$TRANSITION_TO_IA_DAYS" \
        ParameterKey=TransitionToGlacierDays,ParameterValue="$TRANSITION_TO_GLACIER_DAYS" \
        ParameterKey=DailyBackupRetentionDays,ParameterValue="$DAILY_BACKUP_RETENTION_DAYS" \
        ParameterKey=WeeklyBackupRetentionDays,ParameterValue="$WEEKLY_BACKUP_RETENTION_DAYS" \
        ParameterKey=MonthlyBackupRetentionDays,ParameterValue="$MONTHLY_BACKUP_RETENTION_DAYS" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" 2>&1 || error "Failed to create CloudFormation stack"

info "Waiting for stack creation to complete. This may take several minutes..."

# Wait for stack creation to complete
aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION" || {
        error "Stack creation failed or timed out. Check CloudFormation console for details."
    }

# Get stack outputs and display them
info "Stack '$STACK_NAME' created successfully! 🎉"
info "Retrieving stack outputs..."

outputs=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs" \
    --output json \
    --region "$REGION")

echo ""
echo -e "${BLUE}📋 STACK OUTPUTS:${NC}"
echo "$outputs" | jq -r '.[] | .OutputKey + "=" + .OutputValue'
echo ""

info "Deployment completed successfully! 🚀"
