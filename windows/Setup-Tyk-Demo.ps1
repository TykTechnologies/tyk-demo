# Tyk Demo Setup Script
# This PowerShell script checks prerequisites and launches the Tyk demo in WSL
# Note: Run as administrator to ensure all operations can complete successfully

# Check for administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Please close this PowerShell window and re-run it using 'Run as Administrator'." -ForegroundColor Yellow
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Display status messages
function Write-Status {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $color = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "ERROR"   = "Red"
        "WARNING" = "Yellow"
    }[$Type]
    $prefix = if ($Type -eq "INFO") { "==== $Message ====" } else { "[$Type] $Message" }
    Write-Host $prefix -ForegroundColor $color
}

# Check if a command exists
function Test-CommandExists {
    param ([string]$Command)
    return $null -ne (Get-Command -Name $Command -ErrorAction SilentlyContinue)
}

try {
    # Check for Docker
    Write-Status "Checking for Docker CLI"
    if (-not (Test-CommandExists "docker")) {
        Write-Status "Docker is not installed. Please install Docker Desktop from https://www.docker.com/products/docker-desktop/" -Type "ERROR"
        exit 1
    }
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Docker is installed but not running or not responsive. Please ensure Docker Desktop is running." -Type "ERROR"
        exit 1
    }
    Write-Status "Docker is installed and responsive" -Type "SUCCESS"

    # Check for WSL
    Write-Status "Checking WSL availability"
    wsl --status > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "WSL is not installed. Please install it via 'wsl --install' and reboot." -Type "ERROR"
        exit 1
    }
    Write-Status "WSL is available" -Type "SUCCESS"

    # Check for Ubuntu
    Write-Status "Checking for Ubuntu distro"
    $ubuntuInstalled = wsl -l -v | ForEach-Object { $_ -match "Ubuntu" }
    if (-not $ubuntuInstalled) {
        Write-Status "Ubuntu is not installed. Please install it with 'wsl --install -d Ubuntu'" -Type "ERROR"
        exit 1
    }
    Write-Status "Ubuntu is installed" -Type "SUCCESS"

    # Set Ubuntu as default
    wsl --set-default Ubuntu
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to set Ubuntu as default WSL distro." -Type "ERROR"
        exit 1
    }

    # Check Docker integration inside WSL
    Write-Status "Checking Docker inside Ubuntu"
    $dockerInWsl = wsl -d Ubuntu -- which docker 2>$null
    if (-not $dockerInWsl) {
        Write-Status "Docker is not available in WSL. Enable Docker Desktop → Settings → Resources → WSL Integration → Enable for Ubuntu." -Type "ERROR"
        exit 1
    }
    Write-Status "Docker is available inside WSL" -Type "SUCCESS"

    # Run Tyk demo setup
    Write-Status "Running Tyk demo setup in Ubuntu"
    $setupScript = @'
set -e
echo "Updating packages..."
sudo apt update && sudo apt install -y git jq curl

echo "Checking Docker Compose..."
if ! docker compose version > /dev/null 2>&1; then
    echo "ERROR: Docker Compose not available. Enable Docker integration in WSL settings."
    exit 1
fi

if [ -d ~/tyk-demo ]; then
    echo "Updating existing tyk-demo repo..."
    cd ~/tyk-demo && git pull
else
    echo "Cloning tyk-demo repo..."
    git clone https://github.com/TykTechnologies/tyk-demo.git ~/tyk-demo
    cd ~/tyk-demo
fi

echo "Starting Tyk demo..."
chmod +x up.sh && ./up.sh
'@
    $setupScript | wsl -d Ubuntu bash

    if ($LASTEXITCODE -eq 0) {
        Write-Status "Tyk demo setup completed successfully" -Type "SUCCESS"
    } else {
        Write-Status "Tyk demo setup failed inside Ubuntu." -Type "ERROR"
    }

    Read-Host -Prompt "Press Enter to exit"
}
catch {
    Write-Status "An unexpected error occurred: $_" -Type "ERROR"
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}
