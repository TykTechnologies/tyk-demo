# Tyk Demo Environment Setup Script
# This script checks prerequisites and sets up the Tyk demo environment

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandExists {
    param (
        [string]$Command
    )
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-DockerRunning {
    try {
        $dockerInfo = docker info
        return $true
    }
    catch {
        return $false
    }
}

function Set-TykDemoEnvironment {
    # Check Admin Privileges
    if (-not (Test-AdminPrivileges)) {
        Write-Host "This script requires administrator privileges. Please run PowerShell as an administrator." -ForegroundColor Red
        return $false
    }

    # Prerequisite Checks
    $prereqsPassed = $true
    $failedChecks = @()

    # Check Docker Desktop
    if (-not (Test-CommandExists "docker")) {
        $prereqsPassed = $false
        $failedChecks += "Docker Desktop is not installed"
    }

    # Check Docker Compose v2
    if (-not (Test-CommandExists "docker")) {
        $prereqsPassed = $false
        $failedChecks += "Docker Compose v2 (docker compose) is not installed"
    }

    # Check WSL2
    try {
        $wslVersion = (wsl --status) -match "Default Version: 2"
        if (-not $wslVersion) {
            $prereqsPassed = $false
            $failedChecks += "WSL2 is not installed or not set as default"
        }
    }
    catch {
        $prereqsPassed = $false
        $failedChecks += "WSL2 is not installed"
    }

    # Check Docker is Running
    if (-not (Test-DockerRunning)) {
        $prereqsPassed = $false
        $failedChecks += "Docker is not running"
    }

    # Output Prerequisite Check Results
    if (-not $prereqsPassed) {
        Write-Host "Prerequisite checks failed:" -ForegroundColor Red
        foreach ($check in $failedChecks) {
            Write-Host "- $check" -ForegroundColor Yellow
        }
        return $false
    }

    # Verify write permissions for WSL import
    $wslImportPath = "$env:USERPROFILE\WSL\tyk-demo-ubuntu"
    try {
        # Ensure the directory exists
        if (-not (Test-Path -Path $wslImportPath)) {
            New-Item -ItemType Directory -Path $wslImportPath -Force | Out-Null
        }
        
        # Test write permissions
        $testFile = Join-Path $wslImportPath "permissions_test.tmp"
        [System.IO.File]::Create($testFile).Dispose()
        Remove-Item $testFile -Force
    }
    catch {
        Write-Host "Insufficient permissions to create WSL distro directory: $wslImportPath" -ForegroundColor Red
        return $false
    }

    # Check if Tyk Demo Ubuntu distro exists
    $existingDistros = wsl -l -v
    $tykDemoDistroExists = $existingDistros -match "tyk-demo-ubuntu"

    if (-not $tykDemoDistroExists) {
        Write-Host "Creating new WSL2 Ubuntu distro for Tyk Demo..." -ForegroundColor Cyan
        
        # Import Ubuntu as a new distro
        try {
            wsl --import tyk-demo-ubuntu "$wslImportPath" `
                (wsl --exec wsl-export ubuntu)
            
            Write-Host "WSL2 distro 'tyk-demo-ubuntu' created successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to create WSL2 distro." -ForegroundColor Red
            return $false
        }
    }

    # Clone Tyk Demo repository
    Write-Host "Cloning Tyk Demo repository..." -ForegroundColor Cyan
    try {
        wsl -d tyk-demo-ubuntu -e bash -c "git clone https://github.com/TykTechnologies/tyk-demo.git ~/tyk-demo"
        Write-Host "Tyk Demo repository cloned successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to clone Tyk Demo repository." -ForegroundColor Red
        return $false
    }

    return $true
}

# Main Execution
Write-Host "Starting Tyk Demo Environment Setup..." -ForegroundColor Cyan
$setupResult = Set-TykDemoEnvironment

if ($setupResult) {
    Write-Host "Tyk Demo environment setup completed successfully!" -ForegroundColor Green
} else {
    Write-Host "Tyk Demo environment setup encountered errors." -ForegroundColor Red
}