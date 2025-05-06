#!/bin/bash

set -e

# Function to check and install mysql client
install_mysql_client() {
  echo "🔍 Checking MySQL client installation..."

  if ! command -v mysql &> /dev/null; then
    echo "⚠️ MySQL client not found. Attempting installation..."

    if [ -f /etc/debian_version ]; then
      sudo apt update && sudo apt install -y mysql-client
    elif [ -f /etc/redhat-release ]; then
      sudo yum install -y mysql
    elif [ -f /etc/arch-release ]; then
      sudo pacman -Sy mysql-clients --noconfirm
    else
      echo "❌ Unsupported Linux distribution. Please install MySQL client manually."
      exit 1
    fi
  else
    echo "✅ MySQL client is already installed."
  fi
}

# Prompt for database connection settings
read -p "Enter MySQL host [127.0.0.1]: " MYSQL_HOST
MYSQL_HOST=${MYSQL_HOST:-127.0.0.1}

read -p "Enter MySQL user [root]: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-root}

read -p "Enter database name [datashelter_sampledb]: " DATABASE_NAME
DATABASE_NAME=${DATABASE_NAME:-datashelter_sampledb}

# Prompt for password securely
while [[ -z "$MYSQL_PASSWORD" ]]; do
  read -s -p "Enter MySQL password (required): " MYSQL_PASSWORD
  echo
done

# Run dependency check and install if needed
install_mysql_client

# Check if database already exists
DB_EXISTS=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -sse "SHOW DATABASES LIKE '${DATABASE_NAME}';")

if [[ "$DB_EXISTS" == "$DATABASE_NAME" ]]; then
  echo "⚠️ Database '${DATABASE_NAME}' already exists."

  read -p "Do you want to drop and recreate it? [y/N]: " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "❌ Operation canceled. Database not modified."
    exit 0
  fi
fi

# Create and populate the database
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" <<EOF

-- Drop existing database if confirmed
DROP DATABASE IF EXISTS ${DATABASE_NAME};

-- Create new database
CREATE DATABASE ${DATABASE_NAME};
USE ${DATABASE_NAME};

-- Table: address_type
CREATE TABLE address_type (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL
);

-- Table: person
CREATE TABLE person (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100)
);

-- Table: address
CREATE TABLE address (
    id INT AUTO_INCREMENT PRIMARY KEY,
    person_id INT NOT NULL,
    address_type_id INT NOT NULL,
    street VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50),
    zip_code VARCHAR(20),
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (address_type_id) REFERENCES address_type(id)
);

-- Insert address types
INSERT INTO address_type (type_name) VALUES ('Home'), ('Work');

-- Insert people
INSERT INTO person (first_name, last_name, email) VALUES
('Alice', 'Johnson', 'alice.johnson@example.com'),
('Bob', 'Smith', 'bob.smith@example.com'),
('Carol', 'Davis', 'carol.davis@example.com'),
('David', 'Miller', 'david.miller@example.com'),
('Eve', 'Brown', 'eve.brown@example.com');

-- Insert addresses
INSERT INTO address (person_id, address_type_id, street, city, state, zip_code) VALUES
(1, 1, '123 Ocean Ave', 'Seaside', 'CA', '93955'),
(1, 2, '456 Tech Park', 'Silicon Valley', 'CA', '94043'),
(2, 1, '789 Sunset Blvd', 'Los Angeles', 'CA', '90028'),
(2, 2, '321 Corporate Dr', 'Irvine', 'CA', '92618'),
(3, 1, '654 Maple St', 'Springfield', 'IL', '62704'),
(3, 2, '987 Business Rd', 'Chicago', 'IL', '60601'),
(4, 1, '111 Pine Ln', 'Portland', 'OR', '97201'),
(4, 2, '222 Innovation Way', 'Beaverton', 'OR', '97006'),
(5, 1, '333 Elm St', 'Austin', 'TX', '73301'),
(5, 2, '444 Startup Blvd', 'Dallas', 'TX', '75201');

EOF

# Final confirmation and access prompt
echo "✅ Database '${DATABASE_NAME}' created successfully with sample data."

read -p "Do you want to connect to the database now? [y/N]: " CONNECT_NOW
if [[ "$CONNECT_NOW" =~ ^[Yy]$ ]]; then
  mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$DATABASE_NAME"
fi
