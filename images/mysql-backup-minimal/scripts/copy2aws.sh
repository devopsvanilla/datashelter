#!/bin/bash

# AWS S3 configuration
AWS_S3_ENABLED=${AWS_S3_ENABLED}
AWS_S3_ACCESSKEY=${AWS_S3_ACCESSKEY}
AWS_S3_SECRETKEY=${AWS_S3_SECRETKEY}
AWS_S3_REGION=${AWS_S3_REGION}
AWS_S3_BUCKET=${AWS_S3_BUCKET}

BACKUP_DIR="/backup"

if [ "${AWS_S3_ENABLED}" != "true" ]; then
  echo "AWS S3 upload is not enabled. Exiting."
  exit 0
fi

# Export AWS credentials for CLI usage
export AWS_ACCESSKEY_ID=${AWS_S3_ACCESSKEY}
export AWS_SECRET_ACCESSKEY=${AWS_S3_SECRETKEY}
export AWS_DEFAULT_REGION=${AWS_S3_REGION}

for file in ${BACKUP_DIR}/*.sql; do
  if [ -f "$file" ]; then
    echo "Uploading $file to s3://${AWS_S3_BUCKET}/"
    aws s3 cp "$file" "s3://${AWS_S3_BUCKET}/"
  fi
done
