#!/bin/bash
set -e
echo "Starting setup for Tyk demo environment on macOS..."

# Add Homebrew to PATH depending on where it's installed
add_brew_to_path() {
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Error: Homebrew binary not found after install."
    exit 1
  fi
}

# Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  add_brew_to_path
else
  echo "Homebrew is already installed."
  add_brew_to_path
fi

echo "Updating Homebrew..."
brew update

# Install CLI tools
echo "Checking CLI tools..."

# Check jq
if command -v jq >/dev/null 2>&1; then
  echo "jq is already installed."
elif brew list jq >/dev/null 2>&1; then
  echo "jq is installed via Homebrew but not in PATH."
else
  echo "Installing jq..."
  brew install jq
fi

# Check websocat
if command -v websocat >/dev/null 2>&1; then
  echo "websocat is already installed."
elif brew list websocat >/dev/null 2>&1; then
  echo "websocat is installed via Homebrew but not in PATH."
else
  echo "Installing websocat..."
  brew install websocat
fi

# Install GUI apps
echo "Checking GUI applications..."

# Check Rancher Desktop
if [ -d "/Applications/Rancher Desktop.app" ]; then
  echo "Rancher Desktop is already installed in /Applications."
elif brew list --cask rancher >/dev/null 2>&1; then
  echo "Rancher Desktop is installed via Homebrew cask."
else
  echo "Installing Rancher Desktop..."
  brew install --cask rancher
fi

# Check Postman
if [ -d "/Applications/Postman.app" ]; then
  echo "Postman is already installed in /Applications."
elif brew list --cask postman >/dev/null 2>&1; then
  echo "Postman is installed via Homebrew cask."
else
  echo "Installing Postman..."
  brew install --cask postman
fi

# Clone Tyk demo repository
REPO_URL="https://github.com/TykTechnologies/tyk-demo.git"
DEST_DIR="$HOME/tyk-demo"

if [ ! -d "$DEST_DIR" ]; then
  echo "Cloning Tyk demo repository to $DEST_DIR..."
  git clone "$REPO_URL" "$DEST_DIR"
else
  echo "Directory $DEST_DIR already exists. Skipping clone."
fi

# Check if Docker socket is available
echo "Checking Docker availability..."
if [ -S /var/run/docker.sock ]; then
  echo "Docker socket is available at /var/run/docker.sock."
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "Docker is running and accessible."
else
  echo "⚠️  Docker is not running or not accessible."
  echo "   Please ensure Docker (or Rancher Desktop with dockerd enabled) is running before proceeding."
  echo "   If using Rancher Desktop, make sure 'dockerd' is selected in Preferences > Container Engine."
  exit 1
fi

echo "✅ Setup complete. You can now begin using the Tyk demo environment."