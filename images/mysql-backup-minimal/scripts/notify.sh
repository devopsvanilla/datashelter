#!/bin/bash

# Email notification configuration
EMAIL_ENABLED=${EMAIL_ENABLED}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USERNAME=${SMTP_USERNAME}
SMTP_PASSWORD=${SMTP_PASSWORD}
EMAIL_TO=${EMAIL_TO}

# Backup details
BACKUP_TYPE=${BACKUP_TYPE}
SERVER=${SERVER}
DATABASES=${DATABASES}
START_TIME=${START_TIME}
END_TIME=${END_TIME}
BACKUP_SIZE=${BACKUP_SIZE}
TOTAL_SIZE=${TOTAL_SIZE}
COPY_LOCATIONS=${COPY_LOCATIONS}

# Function to send email notification
send_email() {
  local subject=$1
  local body=$2

  if [ "${EMAIL_ENABLED}" == "true" ]; then
    echo -e "Subject:${subject}\n\n${body}" | sendmail -S ${SMTP_HOST}:${SMTP_PORT} -au${SMTP_USERNAME} -ap${SMTP_PASSWORD} ${EMAIL_TO}
  fi
}

# Function to format email content for backup completion
format_completion_email() {
  local body="Backup completed successfully.\n\n"
  body+="Type of Backup: ${BACKUP_TYPE}\n"
  body+="Server: ${SERVER}\n"
  body+="Databases: ${DATABASES}\n"
  body+="Start Time: ${START_TIME}\n"
  body+="End Time: ${END_TIME}\n"
  body+="Backup Size: ${BACKUP_SIZE}\n"
  body+="Total Size: ${TOTAL_SIZE}\n"
  body+="Copy Locations:\n"

  for location in ${COPY_LOCATIONS}; do
    body+="  - ${location}\n"
  done

  echo "${body}"
}

# Function to format email content for backup error
format_error_email() {
  local error_message=$1
  local body="Backup encountered an error.\n\n"
  body+="Type of Backup: ${BACKUP_TYPE}\n"
  body+="Server: ${SERVER}\n"
  body+="Databases: ${DATABASES}\n"
  body+="Start Time: ${START_TIME}\n"
  body+="End Time: ${END_TIME}\n"
  body+="Error: ${error_message}\n"

  echo "${body}"
}

# Main script execution
if [ "$1" == "completion" ]; then
  email_body=$(format_completion_email)
  send_email "Backup Completed" "${email_body}"
elif [ "$1" == "error" ]; then
  error_message=$2
  email_body=$(format_error_email "${error_message}")
  send_email "Backup Error" "${email_body}"
else
  echo "Invalid argument. Use 'completion' or 'error'."
  exit 1
fi
