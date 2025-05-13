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

function ValidateEnvironment {
    $distroName = "tyk-demo"

    # Check for Tyk Demo distro
    $wslDistros = wsl.exe --list --quiet
    if ($wslDistros -contains $distroName) {
        Write-Host "Tyk Demo WSL distro is present." -ForegroundColor Green
    } else {
        Write-Host "Tyk Demo WSL distro not is present." -ForegroundColor Yellow
        Write-Host "Creating Tyk Demo distro... "
        wsl --install ubuntu --name $distroName
        if ($LASTEXITCODE -eq 0) {
            # now install jq
            wsl -d $distroName -e bash -c "apt-get update && apt-get install -y jq"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Done." -ForegroundColor Green
            } else {
                Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
                return $false
            }            
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
            return $false
        }
    }

    # Check for Tyk Demo repo
    $repoPath = "/opt/tyk-demo"
    wsl -d $distroName -e test -d $repoPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tyk Demo repository is present." -ForegroundColor Green
    } else {
        Write-Host "Tyk Demo repository is not present." -ForegroundColor Yellow
        Write-Host "Cloning Tyk Demo repository... "
        wsl -d $distroName -e git clone https://github.com/TykTechnologies/tyk-demo $repoPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done." -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
            return $false
        }
    }

    # Check for Tyk licence
    $envFilePath = "$repoPath/.env"
    wsl -d $distroName -e bash -c "test -f '$envFilePath' && grep '^DASHBOARD_LICENCE=' '$envFilePath'"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tyk licence found." -ForegroundColor Green
    } else {
        Write-Host "Tyk licence not found..." -ForegroundColor Yellow
        $newLicence = Read-Host "Paste your Tyk licence and press return"
        wsl -d $distroName -e bash -c "cd $repoPath && ./scripts/update-env.sh DASHBOARD_LICENCE $newLicence"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done." -ForegroundColor Green
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

Write-Host "Validating Environment" -ForegroundColor Cyan

if (-not (ValidateEnvironment)) {
    Write-Host "Environment check failed." -ForegroundColor Red
    exit 1
}
