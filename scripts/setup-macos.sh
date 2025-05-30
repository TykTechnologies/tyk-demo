#!/bin/bash
set -euo pipefail

# Default values
AUTOINSTALL=false
CLONE_DIR="$HOME/tyk-demo"
DASHBOARD_LICENCE=""

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
- Install CLI tools: jq, websocat, git, curl
- Install GUI apps: Rancher Desktop, Postman
- Clone the Tyk demo repository to: $CLONE_DIR
- Ensure the Tyk licence is available
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

# Check if brew command is missing but binary exists, then fix PATH using add_brew_to_path
check_brew_and_fix_path() {
    if ! command -v brew >/dev/null 2>&1; then
        if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
            echo "brew not found in PATH but binary exists — fixing PATH..."
            add_brew_to_path
        else
            echo -e "${RED}Error:${NC} brew not found and binary does not exist in standard locations."
            return 1
        fi
    fi
}

# Validate if a string is a base64url-encoded JWT
is_valid_jwt() {
    local jwt="$1"
    # A JWT has three parts separated by dots
    if [[ "$jwt" =~ ^[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$ ]]; then
        return 0
    else
        return 1
    fi
}

echo -e "${BLUE}==> Checking Homebrew...${NC}"

# Check if brew command is available
if ! command -v brew >/dev/null 2>&1; then
    # If brew binary exists but PATH is missing it, fix the environment
    if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
        echo -e "${YELLOW}brew binary found, but not in PATH. Fixing...${NC}"
        add_brew_to_path
    else
        # Install Homebrew if no binary is found
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        add_brew_to_path
    fi
else
    echo -e "Homebrew: ${GREEN}ok${NC}"
fi

# Ensure Homebrew is up to date
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
install_cli_tool git
install_cli_tool curl

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

echo -e "${BLUE}==> Checking Repository...${NC}"
# Clone Tyk demo repository
REPO_URL="https://github.com/TykTechnologies/tyk-demo.git"
if [ ! -d "$CLONE_DIR" ]; then
    echo -e "${BLUE}==> Cloning Tyk demo repository to $CLONE_DIR...${NC}"
    git clone "$REPO_URL" "$CLONE_DIR"
else
    echo -e "Repo clone: ${GREEN}ok${NC}"
fi

# Change to the cloned directory
cd "$CLONE_DIR"

# Check licence
echo -e "${BLUE}==> Checking Tyk Licence...${NC}"
if ! grep -q '^DASHBOARD_LICENCE=[^[:space:]]' $CLONE_DIR/.env; then
    echo -e "${YELLOW}Licence missing${NC}"

    if [ -n "$DASHBOARD_LICENCE" ]; then
        echo -e "${YELLOW}Found 'licence' argument...${NC}"

        if ! is_valid_jwt "$DASHBOARD_LICENCE"; then
            echo -e "${RED}Error:${NC} Licence argument does not appear to be a valid JWT."
            echo "Licence provided (first 10 characters): ${licence:0:10}"
            exit 1
        fi
    else
        while true; do
            echo "Please copy your Tyk Licence to the clipboard, then press Enter:"
            read -r

            # Check if pbpaste is available
            if ! command -v pbpaste >/dev/null 2>&1; then
                echo -e "${RED}Error:${NC} pbpaste command is not available."
                exit 1
            fi

            # Get JWT from macOS clipboard - cannot capture directly from read due to input length limits
            DASHBOARD_LICENCE=$(pbpaste 2>/dev/null | tr -d '[:space:]')

            if [[ -z "$DASHBOARD_LICENCE" ]]; then
                echo -e "${YELLOW}Warning:${NC} Licence is empty. Try again."
                continue
            fi

            if is_valid_jwt "$DASHBOARD_LICENCE"; then
                break
            else
                echo -e "${YELLOW}Warning:${NC} Input does not appear to be a valid JWT. Try again."
                echo "Your input (first 10 characters): ${DASHBOARD_LICENCE:0:10}"
            fi
        done
    fi

    if ! ./scripts/update-env.sh DASHBOARD_LICENCE "$DASHBOARD_LICENCE"; then
        echo -e "${RED}Error:${NC} Failed to update the licence in .env file."
        exit 1
    fi
fi
echo -e "Licence: ${GREEN}ok${NC}"

# Check Docker availability
echo -e "${BLUE}==> Checking Docker...${NC}"
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
echo -e "${GREEN}Success. Your Tyk Demo environment is prepared.${NC}"
echo "Repository cloned to: $CLONE_DIR"
