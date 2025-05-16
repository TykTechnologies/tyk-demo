# Tyk Demo Environment Setup Script
# This script checks prerequisites and prepares the Tyk Demo environment
param (
    [string]$DistroName = "Ubuntu",
    [string]$RepoPath = "/usr/local/share/tyk-demo"
)

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ValidateHost {
    # Prerequisite Checks
    $status=$true

    # Check WSL
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "- Windows Subsystem for Linux is installed." -ForegroundColor Green
    } else {
        Write-Host "- Windows Subsystem for Linux is not installed." -ForegroundColor Red
        $status = $false
    }

    # Check if the Docker daemon is running
    docker info > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Docker daemon is running." -ForegroundColor Green
    } else {
        Write-Host "- Docker daemon is not installed." -ForegroundColor Red
        $status = $false
    }

    return $status
}

function ValidateDistro {
    param (
        [string]$distroName,
        [string]$repoPath
    )

    # Check for distro
    $wslDistros = wsl.exe --list --quiet
    if ($wslDistros -contains $distroName) {
        Write-Host "- WSL distro '$distroName' is present." -ForegroundColor Green
    } else {
        Write-Host "- WSL distro '$distroName' not is present." -ForegroundColor Yellow
        Write-Host "Creating WSL distro '$distroName'... "
        wsl --install ubuntu --name $distroName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
            return $false
        }
    }

    # Check if non-root user is available
    $user = wsl -d $distroName -e whoami 2>$null
    if ($user.Trim() -eq "root") {
        Write-Host "- $distroName default user is root"
    } else {
        Write-Host "- $distroName default user is '$($user.Trim())'"
        return $false
    }

    # Check for Tyk Demo repo
    wsl -d $distroName -e test -d $repoPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Tyk Demo repository at '$repoPath' is present." -ForegroundColor Green
    } else {
        Write-Host "- Tyk Demo repository at '$repoPath' is not present." -ForegroundColor Yellow
        Write-Host "Cloning Tyk Demo repository to '$repoPath'... "
        # Create parent directory if needed
        $parentDir = Split-Path -Parent $repoPath
        wsl -d $distroName -e mkdir -p $parentDir
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
        Write-Host "- Tyk licence found." -ForegroundColor Green
    } else {
        Write-Host "- Tyk licence not found..." -ForegroundColor Yellow
        $newLicence = Read-Host "Paste your Tyk licence and press return"
        wsl -d $distroName -e bash -c "cd $repoPath && ./scripts/update-env.sh DASHBOARD_LICENCE $newLicence"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done." -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))." -ForegroundColor Red
            return $false
        }
    }

    # Check for Docker in distro
    wsl -d $distroName -e bash -c "docker version" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Docker is available in $distroName distro." -ForegroundColor Green
    } else {
        Write-Host "- Docker is not available in $distroName distro" -ForegroundColor Red
        Write-Host "To resolve, update Rancher Desktop settings (Preferences -> WSL -> Integrations) to enable WSL integration with $distroName distro."
        return $false
    }

    # Check Docker Compose in distro
    wsl -d $distroName -e bash -c "docker compose version" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Docker Compose is installed in $distroName distro." -ForegroundColor Green
    } else {
        Write-Host "- Docker Compose is not installed in $distroName distro." -ForegroundColor Red
        Write-Host "To resolve, update Rancher Desktop settings (Preferences -> WSL -> Integrations) to enable WSL integration with $distroName distro."
        return $false
    }

    # Check for jq in distro
    wsl -d $distroName -e jq --version > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- jq is installed in $distroName distro." -ForegroundColor Green
    } else {
        Write-Host "- jq is not installed in $distroName distro." -ForegroundColor Red
        Write-Host "Installing jq in $distroName distro."
        wsl -d $distroName -e bash -c "sudo apt-get update && sudo apt-get install -y jq"
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
    return 1
}

Write-Host "Tyk Demo Setup Configuration:" -ForegroundColor Cyan
Write-Host "- Using WSL Distro: $DistroName" -ForegroundColor White
Write-Host "- Using Repository Path: $RepoPath" -ForegroundColor White

Write-Host "Validating Host:" -ForegroundColor Cyan

if (-not (ValidateHost)) {
    Write-Host "Host check failed." -ForegroundColor Red
    return 1
}

Write-Host "Validating Distro:" -ForegroundColor Cyan

if (-not (ValidateDistro -distroName $DistroName -repoPath $RepoPath)) {
    Write-Host "Distro check failed." -ForegroundColor Red
    return 1
}

Write-Host "Tyk Demo environment is prepared successfully." -ForegroundColor Green