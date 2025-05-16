# Tyk Demo Environment Setup Script
# This script checks prerequisites and prepares the Tyk Demo environment
param (
    [string]$DistroName = "tyk-demo-ubuntu",
    [string]$RepoPath = "~/tyk-demo"
)

$distroUser="tyk"

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ValidateHost {
    # Prerequisite Checks
    $status=$true

    # Check WSL is installed
    Write-Host "Check: WSL is installed - " -NoNewLine
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        $status = $false
    }

    # Check if the Docker daemon is available
    Write-Host "Check: Docker daemon available - " -NoNewLine
    docker info > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        $status = $false
    }

    return $status
}

function ValidateDistro {
    param (
        [string]$distroName
    )

    # Check for distro
    Write-Host "Check: Distro '$distroName' present - " -NoNewLine
    $wslDistros = wsl --list --quiet
    if ($wslDistros -contains $distroName) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        $confirmation = Read-Host "Create missing '$distroName' distro? (y/n)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "Please manually create the '$distroName' distro"
            return $false
        }
        Write-Host "Creating distro '$distroName'... "
        wsl --install ubuntu --name $distroName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Distro '$distroName' created" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check if user is available
    Write-Host "Check: User '$distroUser' available in '$distroName' distro - " -NoNewLine
    $userId = wsl -d $distroName -e id -u $distroUser > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        $confirmation = Read-Host "Create missing '$distroUser' user? (y/n)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "Please manually create the '$distroUser' user in $distroName distro"
            return $false
        }
        Write-Host "Creating user '$distroUser' in '$distroName' distro..."
        wsl -d $distroName -e bash -c "sudo adduser --disabled-password --gecos '' $distroUser"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "User '$distroUser' created" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check for Docker in distro
    Write-Host "Check: Docker available in '$distroName' distro - " -NoNewLine
    wsl -d $distroName -e bash -c "docker version" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        Write-Host "Please update Rancher Desktop settings (Preferences -> WSL -> Integrations) to enable WSL integration with '$distroName' distro."
        return $false
    }

    # Check Docker Compose in distro
    Write-Host "Check: Docker Compose available in '$distroName' distro - " -NoNewLine
    wsl -d $distroName -e bash -c "docker compose version" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        Write-Host "Please update Rancher Desktop settings (Preferences -> WSL -> Integrations) to enable WSL integration with '$distroName' distro."
        return $false
    }

    # Check for jq in distro
    Write-Host "Check: jq available in '$distroName' distro - " -NoNewLine
    wsl -d $distroName -e jq --version > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        $confirmation = Read-Host "Install jq in '$distroName' distro? (y/n)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "Please manually install jq in '$distroName' distro."
            return $false
        }
        Write-Host "Installing jq in $distroName distro."
        wsl -d $distroName -u root -e bash -c "sudo apt-get update && sudo apt-get install -y jq"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "jq installed" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    return $true
}

function ValidateRepo() {
    param (
        [string]$distroName,
        [string]$repoPath
    )

    # Check for Tyk Demo repo
    Write-Host "Check: Tyk Demo repository available at '$repoPath' - " -NoNewLine
    wsl -d $distroName -u $tykUser -e bash -c "test -d $repoPath"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        $confirmation = Read-Host "Clone repo to '$repoPath'? (y/n)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "Please manually clone the repo to $repoPath in '$distroName' distro"
            return $false
        }
        Write-Host "Cloning Tyk Demo repository to '$repoPath' in '$distroName' distro..."
        # Create parent directory if needed
        $parentDir = Split-Path -Parent $repoPath
        wsl -d $distroName -u $tykUser -e bash -c "mkdir -p $parentDir" > $null
        wsl -d $distroName -u $tykUser -e bash -c "git clone https://github.com/TykTechnologies/tyk-demo $repoPath" > $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Repo cloned" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check for Tyk licence
    Write-Host "Check: Tyk licence available - " -NoNewLine
    $envFilePath = "$repoPath/.env"
    wsl -d $distroName -u $tykUser -e bash -c "test -f $envFilePath && grep '^DASHBOARD_LICENCE=' $envFilePath" > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        $confirmation = Read-Host "Add Tyk licence? (y/n)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Host "Please manually add a Tyk licence to $envFilePath in '$distroName' distro"
            return $false
        }
        $newLicence = Read-Host "Paste your Tyk licence and press return"
        wsl -d $distroName -u $tykUser -e bash -c "cd $repoPath && ./scripts/update-env.sh DASHBOARD_LICENCE $newLicence"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
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

Write-Host "Tyk Demo Setup Configuration:" -ForegroundColor Cyan
Write-Host "- Using WSL Distro: $DistroName" -ForegroundColor White
Write-Host "- Using Repository Path: $RepoPath" -ForegroundColor White

Write-Host "Validating Host:" -ForegroundColor Cyan
if (ValidateHost) {
    Write-Host "Host validation passed" -ForegroundColor Green
} else {
    Write-Host "Host validation failed" -ForegroundColor Red
    return
}

Write-Host "Validating Distro:" -ForegroundColor Cyan
if (ValidateDistro -distroName $DistroName) {
    Write-Host "Distro validation passed" -ForegroundColor Green
} else {
    Write-Host "Distro validation failed" -ForegroundColor Red
    return
}

Write-Host "Validating Repo:" -ForegroundColor Cyan
if (ValidateRepo -distroName $DistroName -repoPath $RepoPath) {
    Write-Host "Repo validation passed" -ForegroundColor Green
} else {
    Write-Host "Repo validation failed" -ForegroundColor Red
    return
}

Write-Host "Validation complete. Tyk Demo environment is ready." -ForegroundColor Green