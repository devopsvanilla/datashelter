#!/bin/bash

# MySQL connection details
MYSQL_HOST=${MYSQL_HOST}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Backup configuration
BACKUP_TYPE=${BACKUP_TYPE}
BACKUP_DIR="/backup"
BACKUP_FILE="${BACKUP_DIR}/backup-$(date +%Y%m%d%H%M%S).sql"
RETENTION_DAYS=${RETENTION_DAYS}

# Digital Ocean Spaces configuration
DO_SPACES_ENABLED=${DO_SPACES_ENABLED}
DO_SPACES_ACCESSKEY=${DO_SPACES_ACCESSKEY}
DO_SPACES_SECRETKEY=${DO_SPACES_SECRETKEY}
DO_SPACES_REGION=${DO_SPACES_REGION}
DO_SPACES_BUCKET=${DO_SPACES_BUCKET}

# AWS S3 configuration
AWS_S3_ENABLED=${AWS_S3_ENABLED}
AWS_S3_ACCESSKEY=${AWS_S3_ACCESSKEY}
AWS_S3_SECRETKEY=${AWS_S3_SECRETKEY}
AWS_S3_REGION=${AWS_S3_REGION}
AWS_S3_BUCKET=${AWS_S3_BUCKET}

# RSA encryption key
RSA_PUBLICKEY="${RSA_PUBLICKEY}"

# Function to perform MySQL backup
perform_backup() {
  case ${BACKUP_TYPE} in
    schemaTotal)
      mysqldump -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} --all-databases > ${BACKUP_FILE}
      ;;
    schemaIncremental)
      # Implement schema incremental backup logic here
      ;;
    serverTotal)
      mysqldump -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} --all-databases --routines --triggers --events > ${BACKUP_FILE}
      ;;
    serverIncremental)
      # Implement server incremental backup logic here
      ;;
    *)
      echo "Invalid backup type specified."
      exit 1
      ;;
  esac
}

# Function to encrypt backup
encrypt_backup() {
  openssl rsautl -encrypt -inkey ${RSA_PUBLICKEY} -pubin -in ${BACKUP_FILE} -out ${BACKUP_FILE}.enc
  mv ${BACKUP_FILE}.enc ${BACKUP_FILE}
}

# Function to upload backup to Digital Ocean Spaces
upload_to_do_spaces() {
  if [ "${DO_SPACES_ENABLED}" == "true" ]; then
    s3cmd put ${BACKUP_FILE} s3://${DO_SPACES_BUCKET}/ --ACCESSKEY=${DO_SPACES_ACCESSKEY} --SECRETKEY=${DO_SPACES_SECRETKEY} --region=${DO_SPACES_REGION}
  fi
}

# Function to upload backup to AWS S3
upload_to_aws_s3() {
  if [ "${AWS_S3_ENABLED}" == "true" ]; then
    aws s3 cp ${BACKUP_FILE} s3://${AWS_S3_BUCKET}/ --region ${AWS_S3_REGION} --access-key ${AWS_S3_ACCESSKEY} --secret-key ${AWS_S3_SECRETKEY}
  fi
}

# Function to delete old backups
delete_old_backups() {
  find ${BACKUP_DIR} -type f -name "*.sql" -mtime +${RETENTION_DAYS} -exec rm {} \;
}

# Main script execution
perform_backup
encrypt_backup
upload_to_do_spaces
upload_to_aws_s3
delete_old_backups
