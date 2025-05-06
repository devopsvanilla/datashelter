#!/bin/bash

NAMESPACE="datashelter"
ENV_FILE=".env"

prompt_if_empty() {
  local varname="$1"
  local prompt="$2"
  local value="${!varname}"
  if [ -z "$value" ]; then
    read -rp "$prompt: " value
    eval "$varname=\"$value\""
  fi
}

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --mysql-password=*) MYSQL_PASSWORD="${1#*=}"; shift ;;
    --do-access-key=*) DO_SPACES_ACCESSKEY="${1#*=}"; shift ;;
    --do-secret-key=*) DO_SPACES_SECRETKEY="${1#*=}"; shift ;;
    --aws-s3-acesskey=*) AWS_S3_ACCESSKEY="${1#*=}"; shift ;;
    --aws-secret-key=*) AWS_S3_SECRETKEY="${1#*=}"; shift ;;
    --smtp-password=*) SMTP_PASSWORD="${1#*=}"; shift ;;
    --rsa-public-key=*) RSA_PUBLICKEY="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

prompt_if_empty MYSQL_PASSWORD "Informe a senha do MySQL"
prompt_if_empty DO_SPACES_ACCESSKEY "Informe o accessKey do DigitalOcean Spaces"
prompt_if_empty DO_SPACES_SECRETKEY "Informe o secretKey do DigitalOcean Spaces"
prompt_if_empty AWS_S3_ACCESSKEY "Informe o accessKey da AWS S3"
prompt_if_empty AWS_S3_SECRETKEY "Informe o secretKey da AWS S3"
prompt_if_empty SMTP_PASSWORD "Informe a senha do SMTP"
prompt_if_empty RSA_PUBLICKEY "Informe o conteúdo do arquivo de chave pública RSA"

if [ ! -f "$ENV_FILE" ]; then
  echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> "$ENV_FILE"
  echo "DO_SPACES_ACCESSKEY=$DO_SPACES_ACCESSKEY" >> "$ENV_FILE"
  echo "DO_SPACES_SECRETKEY=$DO_SPACES_SECRETKEY" >> "$ENV_FILE"
  echo "AWS_S3_ACCESSKEY=$AWS_S3_ACCESSKEY" >> "$ENV_FILE"
  echo "AWS_S3_SECRETKEY=$AWS_S3_SECRETKEY" >> "$ENV_FILE"
  echo "SMTP_PASSWORD=$SMTP_PASSWORD" >> "$ENV_FILE"
  echo "RSA_PUBLICKEY=$RSA_PUBLICKEY" >> "$ENV_FILE"
  echo ".env criado com as credenciais."
fi

# mysql-secret (MySQL)
kubectl create secret generic mysql-secret \
  --from-literal=password="$MYSQL_PASSWORD" \
  -n $NAMESPACE \
  --dry-run=client -o yaml > mysql-secret.yaml
kubeseal --format yaml < mysql-secret.yaml > mysql-secret-sealedsecret.yaml
rm mysql-secret.yaml

# DigitalOcean Spaces
kubectl create secret generic do-spaces-secret \
  --from-literal=accessKey="$DO_SPACES_ACCESSKEY" \
  --from-literal=secretKey="$DO_SPACES_SECRETKEY" \
  -n $NAMESPACE \
  --dry-run=client -o yaml > do-spaces-secret.yaml
kubeseal --format yaml < do-spaces-secret.yaml > do-spaces-sealedsecret.yaml
rm do-spaces-secret.yaml

# AWS S3
kubectl create secret generic aws-s3-secret \
  --from-literal=accessKey="$AWS_S3_ACCESSKEY" \
  --from-literal=secretKey="$AWS_S3_SECRETKEY" \
  -n $NAMESPACE \
  --dry-run=client -o yaml > aws-s3-secret.yaml
kubeseal --format yaml < aws-s3-secret.yaml > aws-s3-sealedsecret.yaml
rm aws-s3-secret.yaml

# SMTP Secret
kubectl create secret generic smtp-secret \
  --from-literal=password="$SMTP_PASSWORD" \
  -n $NAMESPACE \
  --dry-run=client -o yaml > smtp-secret.yaml
kubeseal --format yaml < smtp-secret.yaml > smtp-sealedsecret.yaml
rm smtp-secret.yaml

# RSA Public Key Secret
kubectl create secret generic rsa-publickey-secret \
  --from-literal=publicKey="$RSA_PUBLICKEY" \
  -n $NAMESPACE \
  --dry-run=client -o yaml > rsa-publickey-secret.yaml
kubeseal --format yaml < rsa-publickey-secret.yaml > rsa-public-key-sealedsecret.yaml
rm rsa-publickey-secret.yaml

echo "SealedSecrets gerados: mysql-secret-sealedsecret.yaml, do-spaces-sealedsecret.yaml, aws-s3-sealedsecret.yaml, smtp-sealedsecret.yaml, rsa-public-key-sealedsecret.yaml"