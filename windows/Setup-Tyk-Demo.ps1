# Improved Tyk Demo Setup Script
# This PowerShell script sets up the Tyk demo in WSL using Tyk-Demo-Ubuntu distribution

# Check for administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges. Please run as Administrator." -ForegroundColor Yellow
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Constants
$WSL_DISTRO_NAME = "Tyk-Demo-Ubuntu"
$DOCKER_INSTALLER_URL = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
$DOCKER_DESKTOP_PATH = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
$TYK_REPO_URL = "https://github.com/TykTechnologies/tyk-demo.git"

# Display status messages with timestamp
function Write-Status($Message, $Type = "INFO") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{"INFO" = "Cyan"; "SUCCESS" = "Green"; "ERROR" = "Red"; "WARNING" = "Yellow"}[$Type]
    Write-Host "[$timestamp] [$Type] $Message" -ForegroundColor $color
}

# Check if a command exists
function Test-CommandExists($Command) {
    return $null -ne (Get-Command -Name $Command -ErrorAction SilentlyContinue)
}

# Install Docker Desktop
function Install-DockerDesktop {
    Write-Status "Installing Docker Desktop..." -Type "INFO"
    $tempDir = Join-Path $env:TEMP "DockerInstall"
    New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue | Out-Null
    $installerPath = Join-Path $tempDir "DockerDesktopInstaller.exe"
    
    try {
        Write-Status "Downloading Docker Desktop installer..." -Type "INFO"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DOCKER_INSTALLER_URL, $installerPath)
        
        if (Test-Path $installerPath) {
            Write-Status "Running Docker Desktop installer..." -Type "INFO"
            $process = Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet" -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Status "Docker Desktop installation completed successfully" -Type "SUCCESS"
                return $true
            } else {
                Write-Status "Docker Desktop installation failed with exit code: $($process.ExitCode)" -Type "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Status "Error installing Docker Desktop: $($_.Exception.Message)" -Type "ERROR"
        return $false
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    return $false
}

# Wait for Docker to be ready
function Wait-ForDocker($MaxSeconds = 60) {
    Write-Status "Waiting for Docker to start (max $MaxSeconds seconds)..." -Type "INFO"
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $MaxSeconds) {
        try {
            $dockerInfo = docker info 2>&1
            if ($dockerInfo -notlike "*Cannot connect*" -and $dockerInfo -notlike "*error*") {
                Write-Status "Docker is ready after $([int]$stopwatch.Elapsed.TotalSeconds) seconds" -Type "SUCCESS"
                return $true
            }
        }
        catch { }
        
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }
    
    Write-Status "Docker did not start within $MaxSeconds seconds" -Type "ERROR"
    return $false
}

# Check if WSL distribution exists
function Test-WslDistributionExists($DistroName) {
    $wslOutput = wsl --list | Out-String
    return $wslOutput -match $DistroName
}

# MAIN SCRIPT EXECUTION
Write-Host "`n=== Tyk Demo Setup for WSL ($WSL_DISTRO_NAME) ===`n" -ForegroundColor Magenta

# 1. Check WSL
Write-Status "Checking WSL availability"
$wslInstalled = Test-CommandExists "wsl"
if (-not $wslInstalled) {
    Write-Status "WSL is not installed. Installing..." -Type "WARNING"
    try {
        wsl --install -ErrorAction Stop
        Write-Status "WSL installation initiated. Please restart your computer and run this script again." -Type "WARNING"
        Read-Host -Prompt "Press Enter to exit"
        exit 0
    }
    catch {
        Write-Status "Error installing WSL: $($_.Exception.Message)" -Type "ERROR"
        exit 1
    }
}
Write-Status "WSL is available" -Type "SUCCESS"

# 2. Check Docker
Write-Status "Checking for Docker"
$dockerInstalled = Test-CommandExists "docker"
if (-not $dockerInstalled) {
    Write-Status "Docker is not installed. Installing..." -Type "WARNING"
    $installDocker = Install-DockerDesktop
    if (-not $installDocker) {
        Write-Status "Docker installation failed. Please install Docker Desktop manually." -Type "ERROR"
        exit 1
    }
    Write-Status "Docker Desktop has been installed. A system restart is required." -Type "WARNING"
    Read-Host -Prompt "Press Enter to exit and restart your computer"
    exit 0
}

# 3. Check if Docker is running
$dockerRunning = $false
try {
    $dockerInfo = docker info 2>&1
    if ($dockerInfo -notlike "*Cannot connect*" -and $dockerInfo -notlike "*error*") {
        $dockerRunning = $true
    }
}
catch { }

if (-not $dockerRunning) {
    Write-Status "Docker is not running. Starting Docker Desktop..." -Type "INFO"
    if (Test-Path $DOCKER_DESKTOP_PATH) {
        Start-Process $DOCKER_DESKTOP_PATH
        $dockerStarted = Wait-ForDocker -MaxSeconds 60
        if (-not $dockerStarted) {
            Write-Status "Docker did not start successfully. Please start Docker Desktop manually and run this script again." -Type "ERROR"
            exit 1
        }
    }
    else {
        Write-Status "Could not find Docker Desktop executable at expected path: $DOCKER_DESKTOP_PATH" -Type "WARNING"
        Write-Status "Please start Docker Desktop manually and run this script again." -Type "WARNING"
        exit 1
    }
}
Write-Status "Docker is running" -Type "SUCCESS"

# 4. Check for Tyk-Demo-Ubuntu distribution
Write-Status "Checking for $WSL_DISTRO_NAME distribution"
$distroExists = Test-WslDistributionExists $WSL_DISTRO_NAME

if (-not $distroExists) {
    Write-Status "$WSL_DISTRO_NAME distribution not found. Creating it based on Ubuntu..." -Type "INFO"
    try {
        # First check if we have Ubuntu, or need to install it temporarily
        $ubuntuExists = Test-WslDistributionExists "Ubuntu"
        if (-not $ubuntuExists) {
            Write-Status "Installing temporary Ubuntu distribution..." -Type "INFO"
            wsl --install -d Ubuntu
            Start-Sleep -Seconds 10  # Give it time to initialize
        }
        
        # Now export Ubuntu and import as our custom distribution
        Write-Status "Creating $WSL_DISTRO_NAME from Ubuntu..." -Type "INFO"
        $tempDir = Join-Path $env:TEMP "WslExport"
        New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue | Out-Null
        $exportPath = Join-Path $tempDir "ubuntu-export.tar"
        
        # Export Ubuntu
        wsl --terminate Ubuntu 2>$null
        wsl --export Ubuntu $exportPath
        
        # Import as our custom distribution
        $installPath = Join-Path $env:LOCALAPPDATA "WSL\$WSL_DISTRO_NAME"
        New-Item -ItemType Directory -Path $installPath -Force -ErrorAction SilentlyContinue | Out-Null
        wsl --import $WSL_DISTRO_NAME $installPath $exportPath
        
        # Clean up
        Remove-Item -Path $exportPath -Force -ErrorAction SilentlyContinue
        
        Write-Status "$WSL_DISTRO_NAME distribution created successfully" -Type "SUCCESS"
    }
    catch {
        Write-Status "Error creating $WSL_DISTRO_NAME: $($_.Exception.Message)" -Type "ERROR"
        exit 1
    }
}
else {
    Write-Status "$WSL_DISTRO_NAME distribution already exists" -Type "SUCCESS"
}

# 5. Check Docker integration in WSL
Write-Status "Checking Docker inside $WSL_DISTRO_NAME"
$dockerInWsl = $null -ne (wsl -d $WSL_DISTRO_NAME -- which docker 2>$null)

if (-not $dockerInWsl) {
    Write-Status "Docker is not available in WSL. Enabling Docker Desktop WSL integration..." -Type "WARNING"
    Write-Status "Please ensure the following steps are completed manually:" -Type "INFO"
    Write-Status "1. Open Docker Desktop → Settings → Resources → WSL Integration" -Type "INFO"
    Write-Status "2. Enable integration for $WSL_DISTRO_NAME and click Apply & Restart" -Type "INFO"
    Read-Host -Prompt "Press Enter once you've enabled Docker WSL integration"
    
    # Verify again
    $dockerInWsl = $null -ne (wsl -d $WSL_DISTRO_NAME -- which docker 2>$null)
    if (-not $dockerInWsl) {
        Write-Status "Docker is still not available in WSL. Please check Docker Desktop settings and try again." -Type "ERROR"
        exit 1
    }
}
Write-Status "Docker is available inside $WSL_DISTRO_NAME" -Type "SUCCESS"

# 6. Update packages and check Docker Compose
Write-Status "Updating packages in $WSL_DISTRO_NAME"
wsl -d $WSL_DISTRO_NAME -- bash -c "sudo apt-get update && sudo apt-get install -y git jq curl nano" | Out-Null

Write-Status "Checking Docker Compose"
$dockerComposeAvailable = (wsl -d $WSL_DISTRO_NAME -- bash -c "docker compose version > /dev/null 2>&1 && echo 'yes' || echo 'no'") -eq "yes"
if (-not $dockerComposeAvailable) {
    Write-Status "Docker Compose not available in $WSL_DISTRO_NAME. Check Docker Desktop WSL integration." -Type "ERROR"
    exit 1
}
Write-Status "Docker Compose is available" -Type "SUCCESS"

# 7. Setup Tyk demo repository
Write-Status "Setting up Tyk demo repository in $WSL_DISTRO_NAME"
$setupOutput = wsl -d $WSL_DISTRO_NAME -- bash -c "if [ -d ~/tyk-demo ]; then cd ~/tyk-demo && git pull; else git clone $TYK_REPO_URL ~/tyk-demo; fi"
if ($LASTEXITCODE -ne 0) {
    Write-Status "Error setting up Tyk demo repository: $setupOutput" -Type "ERROR"
    exit 1
}
Write-Status "Tyk demo repository is ready" -Type "SUCCESS"

# 8. Ready to launch
Write-Host "`n=== Setup Complete ===`n" -ForegroundColor Magenta
Write-Status "Ready to launch Tyk demo" -Type "SUCCESS"
Write-Status "To start the demo, run the following command:" -Type "INFO"
Write-Host "`nwsl -d $WSL_DISTRO_NAME -e bash -c 'cd ~/tyk-demo && ./up.sh'`n" -ForegroundColor Green
Write-Host "`nTo shut down the demo when finished:" -ForegroundColor Cyan
Write-Host "wsl -d $WSL_DISTRO_NAME -e bash -c 'cd ~/tyk-demo && ./down.sh'`n" -ForegroundColor White

Read-Host -Prompt "Press Enter to exit"