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

function Set-TykDemoEnvironment {
    # Check Admin Privileges
    if (-not (Test-AdminPrivileges)) {
        Write-Host "This script requires administrator privileges. Please run PowerShell as an administrator." -ForegroundColor Red
        return $false
    }

    # Prerequisite Checks
    $failedChecks = @()

    # Check Docker Desktop
    if (-not (Test-CommandExists "docker")) {
        $failedChecks += "Docker Desktop is not installed"
    }

    # Check Docker Compose v2
    if (-not (Test-CommandExists "docker compose")) {
        $failedChecks += "Docker Compose is not installed"
    }

    # Check WSL2
    try {
        $wslVersionOutput = wsl --version 2>&1
    } catch {
        $failedChecks += "WSL is not installed or not available in PATH."
    }

    if ($wslVersionOutput -match "WSL version:\s*([\d\.]+)") {
        $versionString = $Matches[1]
        $version = [version]$versionString

        if ($version.Major -lt 2) {
            $failedChecks += "WSL version $versionString is too old. WSL 2.x or higher is required."
        }
    } else {
        $failedChecks += "Could not determine WSL version from output:"
    }

    # Check if the Docker Desktop process is running
    $dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue

    if (-not $dockerProcess) {
        $failedChecks += "Docker Desktop is not running."
    }

    # Output Prerequisite Check Results
    if ($failedChecks.Count -gt 0) {
        Write-Host "Prerequisite checks failed:" -ForegroundColor Red
        foreach ($check in $failedChecks) {
            Write-Host "- $check" -ForegroundColor Yellow
        }
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