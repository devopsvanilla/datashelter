#!/bin/bash

set -e

# Function to handle errors
error_handler() {
    echo "❌ Error occurred in script: $(basename "$0") at line: $1"
    exit 1
}

# Trap errors and call the error_handler function
trap 'error_handler $LINENO' ERR

# Function to check if Homebrew is already installed
check_brew() {
    if command -v brew &>/dev/null; then
        echo "✅ Homebrew is already installed! Everything is good to go."
        exit 0
    else
        echo -e
        echo "⏳ Homebrew not found. Starting installation..."
    fi
}

# Function to detect the Linux distribution
check_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

# Function to install required dependencies based on the Linux distribution
install_dependencies() {
    local distro=$1
    if [[ $distro == "ubuntu" || $distro == "debian" ]]; then
        echo -e
        echo "⏳ Installing dependencies for Debian-based distribution..."
        sudo apt-get update
        sudo apt-get install -y build-essential curl file git
    elif [[ $distro == "fedora" || $distro == "centos" ]]; then
        echo -e
        echo "⏳ Installing dependencies for Red Hat-based distribution..."
        sudo yum groupinstall -y 'Development Tools'
        sudo yum install -y curl file git
    elif [[ $distro == "arch" ]]; then
        echo -e
        echo "⏳ Installing dependencies for Arch Linux..."
        sudo pacman -Sy --noconfirm base-devel curl file git
    else
        echo -e
        echo "Unsupported distribution detected."
        exit 1
    fi
}

# Function to install Homebrew
install_brew() {
    if command -v brew &>/dev/null; then
        echo "✅ Homebrew is already installed! Skipping installation."
    else
        echo -e
        echo "⏳ Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi
}

# Function to configure the environment for Homebrew
setup_brew_env() {
    if test -d ~/.linuxbrew || test -d /home/linuxbrew/.linuxbrew; then
        echo "✅ Homebrew environment is already configured! Skipping setup."
    else
        echo -e
        echo "⏳ Configuring Homebrew environment..."
        test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
        test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        test -r ~/.bash_profile && echo "eval $(brew --prefix)/bin/brew shellenv" >>~/.bash_profile
    fi
}

# Main script execution starts here
echo "⏳ Checking for Homebrew installation..."
check_brew

distro=$(check_distro)
echo "ℹ️ Detected Linux distribution: $distro"

echo "⏳ Installing required dependencies..."
install_dependencies "$distro"

echo "⏳ Proceeding with Homebrew installation..."
install_brew

echo "⏳ Setting up Homebrew environment..."
setup_brew_env

echo "✅ Homebrew has been successfully installed! Check it using 'brew --version'."