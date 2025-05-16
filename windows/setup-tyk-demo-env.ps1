# Tyk Demo Environment Setup Script
# This script checks prerequisites and prepares the Tyk Demo environment
param (
    [string]$DistroName = "Ubuntu",
    [string]$RepoPath = "/opt/tyk-demo"
)

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-WSL {
    Write-Host "Installing Windows Subsystem for Linux... " -NoNewline
    try {
        # This will install WSL2 with Ubuntu by default
        wsl --install
        
        Write-Host "WSL installation initiated." -ForegroundColor Green
        Write-Host "NOTE: A system restart is required to complete the WSL installation." -ForegroundColor Yellow
        
        $restartNow = Read-Host "Would you like to restart now? (y/n)"
        if ($restartNow -eq "y") {
            Restart-Computer -Force
        } else {
            Write-Host "Please restart your computer manually to complete the WSL installation." -ForegroundColor Yellow
            Write-Host "After restarting, please run this script again." -ForegroundColor Yellow
        }
        
        # Return false since we need a restart before continuing
        return $false
    }
    catch {
        Write-Host "Failed to install WSL: $_" -ForegroundColor Red
        return $false
    }
}

function ValidatePrerequisites {
    # Prerequisite Checks
    $status=$true

    # Check WSL
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "- Windows Subsystem for Linux is installed." -ForegroundColor Green
    } else {
        Write-Host "- Windows Subsystem for Linux is not installed." -ForegroundColor Red
        
        $installWSL = Read-Host "Would you like to install Windows Subsystem for Linux now? (y/n)"
        if ($installWSL -eq "y") {
            $wslInstalled = Install-WSL
            if (-not $wslInstalled) {
                $status = $false
            }
        } else {
            $status = $false
        }
    }

    # Check Docker
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "- Docker is installed." -ForegroundColor Green
    } else {
        Write-Host "- Docker is not installed." -ForegroundColor Red
        $status=$false
    }

    # Check Docker Compose 
    docker compose version > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Docker Compose is installed." -ForegroundColor Green
    } else {
        Write-Host "- Docker Compose is not installed." -ForegroundColor Red
        $status=$false
    }

    # Check if the Docker daemon is running
    docker info > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Docker daemon is running." -ForegroundColor Green
    } else {
        Write-Host "- Docker daemon is not installed." -ForegroundColor Red
    }

    return $status
}

function ValidateEnvironment {
    param (
        [string]$distroName,
        [string]$repoPath
    )

    # Check for Tyk Demo distro
    $wslDistros = wsl.exe --list --quiet
    if ($wslDistros -contains $distroName) {
        Write-Host "- Tyk Demo WSL distro '$distroName' is present." -ForegroundColor Green
    } else {
        Write-Host "- Tyk Demo WSL distro '$distroName' not is present." -ForegroundColor Yellow
        Write-Host "Creating Tyk Demo distro '$distroName'... "
        wsl --install ubuntu --name $distroName
        if ($LASTEXITCODE -eq 0) {
            # now install jq
            wsl -d $distroName -e bash -c "apt-get update && apt-get install -y jq"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Done." -ForegroundColor Green
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
    $dockerResponse = wsl -d $distroName -e docker version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "- Docker is available in Tyk Demo distro." -ForegroundColor Green
    } else {
        Write-Host "- Docker is not available in Tyk Demo distro" -ForegroundColor Red
        Write-Host "To resolve, update Docker Desktop (Settings -> Resources -> WSL Integration) to enable WSL integration with $distroName distro. Apply changes and restart Docker Desktop."
    }

    return $true
}

# Main Execution

# Check Admin Privileges
if (-not (Test-AdminPrivileges)) {
    Write-Host "This script requires administrator privileges. Please run PowerShell as an administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Tyk Demo Setup Configuration:" -ForegroundColor Cyan
Write-Host "- Using WSL Distro: $DistroName" -ForegroundColor White
Write-Host "- Using Repository Path: $RepoPath" -ForegroundColor White

Write-Host "Validating Prerequisites:" -ForegroundColor Cyan

if (-not (ValidatePrerequisites)) {
    Write-Host "Prerequisite check failed." -ForegroundColor Red
    exit 1
}

Write-Host "Validating Environment:" -ForegroundColor Cyan

if (-not (ValidateEnvironment -distroName $DistroName -repoPath $RepoPath)) {
    Write-Host "Environment check failed." -ForegroundColor Red
    exit 1
}

Write-Host "Tyk Demo environment is prepared successfully." -ForegroundColor Green