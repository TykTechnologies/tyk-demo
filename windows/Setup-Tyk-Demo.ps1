# Tyk Demo Environment Setup Script
# This script checks prerequisites and prepares the Tyk Demo environment

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ValidatePrerequisites {
    # Prerequisite Checks
    $status=$true

    # Check Docker
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "Docker is installed." -ForegroundColor Green
    } else {
        Write-Host "Docker is not installed." -ForegroundColor Red
        $status=$false
    }

    # Check Docker Compose 
    $composeAvailable = docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker Compose is installed." -ForegroundColor Green
    } else {
        Write-Host "Docker Compose is not installed." -ForegroundColor Red
        $status=$false
    }

    # Check WSL
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "Windows Subsystem for Linux is installed." -ForegroundColor Green
    } else {
        Write-Host "Windows Subsystem for Linux is not installed." -ForegroundColor Red
        $status=$false
    }

    # Check if the Docker Desktop process is running
    if (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue) {
        Write-Host "Docker Desktop is running." -ForegroundColor Green
    } else {
        Write-Host "Docker Desktop is not installed." -ForegroundColor Red
        $status=$false
    }

    return $status
}

function PrepareEnvironment {
    $tykDemoDistroName = "tyk-demo"

    # Check for Tyk Demo distro
    $wslDistros = wsl.exe --list --quiet
    if ($wslDistros -contains $tykDemoDistroName) {
        Write-Host "Tyk Demo WSL distro present." -ForegroundColor Green
    } else {
        Write-Host "Tyk Demo WSL distro not present." -ForegroundColor Yellow
        Write-Host "Creating Tyk Demo distro... " -NoNewline
        wsl --install ubuntu --name $tykDemoDistroName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done." -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
            return $false
        }
    }

    # Check for Tyk Demo repo
    $tykDemoRepoPath = "~/tyk-demo"
    wsl -d $tykDemoDistroName -e bash -c "test -d '$tykDemoRepoPath'"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "The Tyk Demo repository exists." -ForegroundColor Green
    } else {
        Write-Host "The Tyk Demo repository does not exist." -ForegroundColor Yellow
        Write-Host "Cloning Tyk Demo repository... " -NoNewline
        wsl -d $tykDemoDistroName -e bash -c 'git clone https://github.com/TykTechnologies/tyk-demo $tykDemoRepoPath'
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done."
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
            return $false
        }
    }

    return $true
}

# Main Execution

# Check Admin Privileges
if (-not (Test-AdminPrivileges)) {
    Write-Host "This script requires administrator privileges. Please run PowerShell as an administrator." -ForegroundColor Red
    return $false
}

Write-Host "Validating Prerequisites" -ForegroundColor Cyan

if (-not (ValidatePrerequisites)) {
    Write-Host "Prerequisite check failed." -ForegroundColor Red
    exit 1
}

Write-Host "Preparing Environment" -ForegroundColor Cyan

if (-not (PrepareEnvironment)) {
    Write-Host "Environment preparation failed." -ForegroundColor Red
    exit 1
}
