#!/bin/bash
set -euo pipefail

# Default values
AUTOINSTALL=false
CLONE_DIR="$HOME/tyk-demo"

# ANSI colours
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No colour

# Print help message
print_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --autoinstall         Automatically proceed with installation without prompting
  --clone-dir DIR       Override the git clone directory (default: \$HOME/tyk-demo)
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
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}==> Starting setup for Tyk demo environment on macOS...${NC}"

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
        echo -e "${RED}Error:${NC} Homebrew binary not found after install."
        exit 1
    fi
}

echo -e "${BLUE}==> Checking Homebrew...${NC}"

# Install Homebrew if needed
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    add_brew_to_path
else
    echo -e "Homebrew: ${GREEN}ok${NC}"
fi

# Ensure Homebrew is up-to-date
brew update

# Install CLI tools
install_cli_tool() {
    local tool="$1"
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "$tool: ${GREEN}ok${NC}"
    else
        echo -e "${YELLOW}Installing $tool...${NC}"
        brew install "$tool"
    fi
}

echo -e "${BLUE}==> Checking CLI tools...${NC}"
install_cli_tool jq
install_cli_tool websocat

# Install GUI apps
install_cask_app() {
    local app="$1"
    local app_path="/Applications/${2:-$app}.app"
    if [ -d "$app_path" ]; then
        echo -e "$app: ${GREEN}ok${NC}"
    elif brew list --cask "$app" >/dev/null 2>&1; then
        echo -e "$app (cask): ${GREEN}ok${NC}"
    else
        echo -e "${YELLOW}Installing $app...${NC}"
        brew install --cask "$app"
    fi
}

echo -e "${BLUE}==> Checking GUI applications...${NC}"
install_cask_app rancher "Rancher Desktop"
install_cask_app postman "Postman"

# Clone Tyk demo repository
REPO_URL="https://github.com/TykTechnologies/tyk-demo.git"
if [ ! -d "$CLONE_DIR" ]; then
    echo -e "${BLUE}==> Cloning Tyk demo repository to $CLONE_DIR...${NC}"
    git clone "$REPO_URL" "$CLONE_DIR"
else
    echo -e "Repo clone: ${GREEN}ok${NC}"
fi

# Check Docker availability
echo -e "${BLUE}==> Checking Docker availability...${NC}"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo -e "Docker: ${GREEN}ok${NC}"
else
    echo -e "${RED}Error:${NC} Docker is not accessible."
    echo "Ensure that:"
    echo "  - Docker or Rancher Desktop is running with 'dockerd' enabled"
    echo "  - The docker CLI tools are available in your PATH"
    echo "  - You have the necessary permissions to access the Docker socket"
    exit 1
fi

echo "---------------------------------------------------"
echo -e "${GREEN}Setup complete. You can now begin using the Tyk demo environment.${NC}"
echo "Repository cloned to: $CLONE_DIR"
