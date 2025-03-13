#!/bin/bash
# filepath: /home/devopsvanilla/_prj/devopsvanilla/datashelter/setup/create-awss3.sh

# This script creates a secure S3 bucket and an IAM user with restricted access.
# The bucket is configured to enforce encryption (AES256) and only allows secure transport (HTTPS).
# The IAM user has limited permissions:
# - Can upload files to the bucket
# - Can set object expiration metadata via tagging
# - Can list bucket contents
# - CANNOT delete files
# These security measures ensure the bucket is used exclusively as a file repository
# with controlled expiration settings and no risk of accidental deletions.

# Function to display usage information
function display_usage {
    echo -e "❌ Error: Missing required parameters"
    echo -e "\nUsage: $0 --bucketname <bucket_name> --region <aws_region> --iamuser <iam_username> --owner <owner_name> --application <application_name>"
    echo -e "\nRequired parameters:"
    echo -e "  --bucketname \tName for the S3 bucket"
    echo -e "  --region \tAWS region to create resources in"
    echo -e "  --iamuser \tName for the IAM user"
    echo -e "  --owner \tOwner name for resource tagging"
    echo -e "  --application \tApplication name for resource tagging"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --bucketname)
            BUCKET_NAME="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --iamuser)
            IAM_USER="$2"
            shift 2
            ;;
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --application)
            APPLICATION="$2"
            shift 2
            ;;
        *)
            echo "❌ Unknown option: $1"
            display_usage
            ;;
    esac
done

# Check if required parameters are provided
if [ -z "$BUCKET_NAME" ] || [ -z "$AWS_REGION" ] || [ -z "$IAM_USER" ] || [ -z "$OWNER" ] || [ -z "$APPLICATION" ]; then
    display_usage
fi

# Define other variables
POLICY_NAME="S3UploadOnlyPolicy-${IAM_USER}"
AUTHOR="https://github.com/devopsvanilla/datashelter"

# Function to check the exit status of the last command and exit if it failed
function check_exit_status {
    if [ $? -ne 0 ]; then
        echo "❌ Error: $1"
        exit 1
    fi
}

# Create the S3 bucket
if [ "$AWS_REGION" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi
check_exit_status "Failed to create S3 bucket"

# Add tags to the bucket
aws s3api put-bucket-tagging --bucket "$BUCKET_NAME" --tagging '{
    "TagSet": [
        {"Key": "Description", "Value": "Secure bucket for file repository with restricted access"},
        {"Key": "Owner", "Value": "'"$OWNER"'"},
        {"Key": "Application", "Value": "'"$APPLICATION"'"},
        {"Key": "Author", "Value": "'"$AUTHOR"'"}
    ]
}'
check_exit_status "Failed to add tags to S3 bucket"

echo "Bucket $BUCKET_NAME successfully created with tags."

# Ensure the bucket exists before applying the bucket policy
aws s3api head-bucket --bucket "$BUCKET_NAME"
check_exit_status "Bucket does not exist"

# Apply security policies to the bucket
cat > bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyUnencryptedUploads",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*",
            "Condition": {
                "StringNotEquals": {
                    "s3:x-amz-server-side-encryption": "AES256"
                }
            }
        },
        {
            "Sid": "EnforceSecureTransport",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": ["arn:aws:s3:::$BUCKET_NAME", "arn:aws:s3:::$BUCKET_NAME/*"],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": false
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file://bucket-policy.json
check_exit_status "Failed to apply bucket policy"

echo "Security policies applied to bucket $BUCKET_NAME."

# Create IAM user with restricted access and add tags
aws iam create-user --user-name "$IAM_USER"
check_exit_status "Failed to create IAM user"

aws iam tag-user --user-name "$IAM_USER" --tags "[
    {\"Key\":\"Description\",\"Value\":\"IAM user with limited permissions for secure file uploads\"},
    {\"Key\":\"Owner\",\"Value\":\"$OWNER\"},
    {\"Key\":\"Application\",\"Value\":\"$APPLICATION\"},
    {\"Key\":\"Author\",\"Value\":\"$AUTHOR\"}
]"
check_exit_status "Failed to tag IAM user"

echo "IAM user $IAM_USER created with tags."

# Create IAM policy
cat > iam-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUploadFiles",
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        },
        {
            "Sid": "AllowSetExpirationMetadata",
            "Effect": "Allow",
            "Action": "s3:PutObjectTagging",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        },
        {
            "Sid": "AllowListBucketContents",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::$BUCKET_NAME"
        },
        {
            "Sid": "DenyFileDeletion",
            "Effect": "Deny",
            "Action": "s3:DeleteObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
EOF

# Create policy with tags
aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://iam-policy.json --tags "[
    {\"Key\":\"Owner\",\"Value\":\"$OWNER\"},
    {\"Key\":\"Application\",\"Value\":\"$APPLICATION\"},
    {\"Key\":\"Author\",\"Value\":\"$AUTHOR\"}
]"
check_exit_status "Failed to create IAM policy"

# Attach policy to the user
aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME"
check_exit_status "Failed to attach policy to IAM user"

# Create access credentials for the user
aws iam create-access-key --user-name "$IAM_USER" > credentials.json
check_exit_status "Failed to create access keys for IAM user"

echo "IAM user $IAM_USER created with restricted credentials. Check credentials.json for access keys."