# Tyk Demo Setup Script
# This PowerShell script sets up the necessary prerequisites and launches the Tyk demo
# Note: Run as administrator to ensure all operations can complete successfully

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Please close this PowerShell windows, then reload PowerShell using the 'Run as Administrator' option." -ForegroundColor Yellow
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Function to display status messages with color
function Write-Status {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Type = "INFO"
    )
    
    switch ($Type) {
        "INFO" { 
            Write-Host "==== $Message ====" -ForegroundColor Cyan 
        }
        "SUCCESS" { 
            Write-Host "[SUCCESS] $Message" -ForegroundColor Green 
        }
        "ERROR" { 
            Write-Host "[ERROR] $Message" -ForegroundColor Red 
        }
        "WARNING" { 
            Write-Host "[WARNING] $Message" -ForegroundColor Yellow 
        }
    }
}

# Function to check if a command exists
function Test-CommandExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command -Name $Command -ErrorAction SilentlyContinue)
    return $exists
}

try {
    # -------------------------------
    # Step 1: Check for Docker Desktop
    # -------------------------------
    Write-Status "Checking for Docker Desktop installation"
    
    if (-not (Test-CommandExists "docker")) {
        Write-Status "Docker Desktop is not installed. Please install it from https://www.docker.com/products/docker-desktop/" -Type "ERROR"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
    
    Write-Status "Docker is installed" -Type "SUCCESS"
    
    # -------------------------------
    # Step 2: Check if Docker Desktop is running and the daemon is responsive
    # -------------------------------
    Write-Status "Checking if Docker Desktop is running"
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    if (-not $dockerProcess) {
      Write-Status "Attempting to start Docker Desktop" -Type "INFO"
      Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe" -NoNewWindow
      Start-Sleep -Seconds 10
      $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
      if (-not $dockerProcess) {
        Write-Status "Failed to start Docker Desktop. Please start it manually and re-run the script." -Type "ERROR"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
      }
    }
    
    # Check if Docker daemon is responsive
    try {
        $dockerInfo = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker daemon is not responsive"
        }
    }
    catch {
        Write-Status "Docker daemon is not responsive. Please ensure Docker Desktop is fully started." -Type "ERROR"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
    
    Write-Status "Docker Desktop is running and responsive" -Type "SUCCESS"
    
    # -------------------------------
    # Step 3: Check for WSL
    # -------------------------------
    Write-Status "Checking WSL status"
    
    try {
        $wslStatus = wsl --status 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "WSL is not installed"
        }
    }
    catch {
        Write-Status "WSL is not installed. Installing..." -Type "WARNING"
        wsl --install
        Write-Status "Please reboot your computer and re-run this script." -Type "WARNING"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
    
    # Check WSL version
    $wslVersion = (wsl --status | Select-String -Pattern "Default Version" -SimpleMatch).Line
    if (-not ($wslVersion -match "2")) {
        Write-Status "Setting WSL 2 as default version" -Type "INFO"
        wsl --set-default-version 2
    }
    
    Write-Status "WSL is properly installed" -Type "SUCCESS"
    
    # -------------------------------
    # Step 4: Check for Ubuntu
    # -------------------------------
    Write-Status "Checking for Ubuntu distro"
    
    $ubuntuInstalled = wsl -l -v | Select-String -Pattern "Ubuntu" -SimpleMatch
    if (-not $ubuntuInstalled) {
        Write-Status "Ubuntu not found. Installing via WSL..." -Type "WARNING"
        wsl --install -d Ubuntu
        Write-Status "Ubuntu installation starting. Please follow on-screen instructions." -Type "WARNING"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
    
    Write-Status "Ubuntu is installed" -Type "SUCCESS"
    
    # -------------------------------
    # Step 5: Set Ubuntu as default and run setup
    # -------------------------------
    Write-Status "Setting Ubuntu as default distro"
    
    wsl --set-default Ubuntu
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Failed to set Ubuntu as the default WSL distro." -Type "ERROR"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
    
    Write-Status "Ubuntu is set as default WSL distro" -Type "SUCCESS"
    
    # Check Docker Desktop WSL integration
    Write-Status "Checking Docker integration with WSL"
    
    $dockerIntegration = wsl -d Ubuntu -- which docker 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Docker integration with WSL is not enabled. Please enable WSL integration for Ubuntu in Docker Desktop → Settings → Resources → WSL Integration." -Type "ERROR"
        Read-Host -Prompt "Press Enter to exit"
        exit 1
    }
    
    Write-Status "Docker integration with WSL is enabled" -Type "SUCCESS"
    
    # -------------------------------
    # Step 6: Starting tyk-demo in Ubuntu
    # -------------------------------
    Write-Status "Starting Tyk demo setup in Ubuntu"
    
    $setupScript = @'
    set -e
    echo "Updating Ubuntu packages..."
    sudo apt update && sudo apt install -y git jq curl

    echo "Checking Docker Compose availability..."
    if ! docker compose version > /dev/null 2>&1; then
        echo "ERROR: Docker Compose is not available in WSL. Enable WSL integration for Ubuntu in Docker Desktop → Settings → Resources → WSL Integration."
        exit 1
    fi

    # Check if tyk-demo directory exists
    if [ -d ~/tyk-demo ]; then
        echo "Tyk demo directory already exists, updating..."
        cd ~/tyk-demo
        git pull
    else
        echo "Cloning Tyk demo repository..."
        git clone https://github.com/TykTechnologies/tyk-demo.git ~/tyk-demo
        cd ~/tyk-demo
    fi
    
    echo "Setting up Tyk demo..."
    chmod +x up.sh
    ./up.sh
'@
    
    # Run the setup script in WSL
    $setupScript | wsl -d Ubuntu bash
    
    if ($LASTEXITCODE -ne 0) {
        Write-Status "There was an error setting up the Tyk demo in Ubuntu." -Type "ERROR"
    } else {
        Write-Status "Tyk demo setup completed successfully!" -Type "SUCCESS"
    }
    
    Read-Host -Prompt "Press Enter to exit"
}
catch {
    Write-Status "An unexpected error occurred: $_" -Type "ERROR"
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}