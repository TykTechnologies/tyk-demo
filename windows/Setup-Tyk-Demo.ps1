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
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        return $true
    } else {
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
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $failedChecks += "Docker Desktop is not installed"
    }

    # Check Docker Compose 
    $composeAvailable = docker compose version 2>$null
    if (-not ($LASTEXITCODE -eq 0)) {
        $failedChecks += "Docker Compose is not installed"
    }

    # Check WSL
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        $failedChecks += "WSL is not installed"
    }

    # Check if the Docker Desktop process is running
    if (-not (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue)) {
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