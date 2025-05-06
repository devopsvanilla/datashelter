#!/usr/bin/env bash

# If the .env file already exists, get the MYSQL_ROOT_PASSWORD from it
if [ -f .env ]; then
  source .env
else
    # Generate a password for the MySQL root user
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
    
    # Create a .env file to store the password
    echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" > .env
fi

# Create a Docker container for MySQL
docker run -d \
  --name=mysql-container \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
  mysql:latest

echo "MySQL container started with root password: $MYSQL_ROOT_PASSWORD"
