#!/bin/bash
set -euo pipefail

# Default values
AUTOINSTALL=false
CLONE_DIR="$HOME/tyk-demo"
DASHBOARD_LICENCE=""

# Print help message
print_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --autoinstall         Automatically proceed with installation without prompting
  --clone-dir DIR       Override the git clone directory (default: \$HOME/tyk-demo)
  --licence LICENCE     Provide the Tyk dashboard licence
  -h, --help            Show this help message
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --autoinstall)
            AUTOINSTALL=true
            shift
            ;;
        --clone-dir)
            CLONE_DIR="$2"
            shift 2
            ;;
        --licence)
            DASHBOARD_LICENCE="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🔧 Starting setup for Tyk demo environment on macOS..."

# Confirm continuation unless autoinstall is set
if [ "$AUTOINSTALL" = false ]; then
    cat <<EOF

This script will:
- Install required dependencies via Homebrew
- Install CLI tools: jq, websocat
- Install GUI apps: Rancher Desktop, Postman
- Clone the Tyk demo repository to: $CLONE_DIR
- Ensure Docker is available

EOF
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "Setup cancelled."; exit 0; }
fi

# Add Homebrew to PATH depending on location
add_brew_to_path() {
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "❌ Homebrew binary not found after install."
        exit 1
    fi
}

# Install Homebrew if needed
if ! command -v brew >/dev/null 2>&1; then
    echo "📦 Homebrew not found. Installing..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    add_brew_to_path
else
    echo "✅ Homebrew is already installed."
fi

echo "🔄 Updating Homebrew..."
brew update

# Install CLI tools
install_cli_tool() {
    local tool="$1"
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool is already installed."
    else
        echo "📦 Installing $tool..."
        brew install "$tool"
    fi
}

echo "🔍 Checking CLI tools..."
install_cli_tool jq
install_cli_tool websocat

# Install GUI apps
install_cask_app() {
    local app="$1"
    local app_path="/Applications/${2:-$app}.app"
    if [ -d "$app_path" ]; then
        echo "✅ $app is already installed in $app_path."
    elif brew list --cask "$app" >/dev/null 2>&1; then
        echo "✅ $app is installed via Homebrew cask."
    else
        echo "📦 Installing $app..."
        brew install --cask "$app"
    fi
}

echo "🖥️ Checking GUI applications..."
install_cask_app rancher "Rancher Desktop"
install_cask_app postman "Postman"

# Add Rancher Docker CLI to PATH
ensure_rancher_docker_in_path() {
    local rancher_docker="$HOME/.rd/bin/docker"
    if [[ ":$PATH:" != *":$HOME/.rd/bin:"* ]] && [ -x "$rancher_docker" ]; then
        export PATH="$HOME/.rd/bin:$PATH"
        echo "🛠️ Added ~/.rd/bin to PATH for this session."
    fi
}

# Clone Tyk demo repository
REPO_URL="https://github.com/TykTechnologies/tyk-demo.git"
if [ ! -d "$CLONE_DIR" ]; then
    echo "📁 Cloning Tyk demo repository to $CLONE_DIR..."
    git clone "$REPO_URL" "$CLONE_DIR"
else
    echo "✅ Directory $CLONE_DIR already exists. Skipping clone."
fi

# Check Docker availability
echo "🐳 Checking Docker availability..."
if [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket is available."
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "✅ Docker is running and accessible."
else
    echo "❌ Docker is not accessible."
    echo "   Ensure Docker or Rancher Desktop is running with 'dockerd' enabled."
    exit 1
fi

# Update licence if provided
if [ -n "$DASHBOARD_LICENCE" ]; then
    echo "🔐 Updating licence using update-env.sh..."
    (cd "$CLONE_DIR" && ./scripts/update-env.sh DASHBOARD_LICENCE "$DASHBOARD_LICENCE")
    echo "✅ Licence updated in .env"
fi

echo "✅ Setup complete. You can now begin using the Tyk demo environment."
echo "📂 Repository cloned to: $CLONE_DIR"