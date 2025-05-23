# Tyk Demo Environment Setup Script
# This script checks prerequisites and prepares the Tyk Demo environment
param (
    [string]$DistroName = "tyk-demo-ubuntu",
    [string]$RepoPath = "~/tyk-demo",
    [string]$DistroUser = "tyk",
    [switch]$AutoInstall = $false
)

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ValidateHost {
    # Prerequisite Checks
    $status=$true

    # Check WSL is installed
    Write-Host "Checking WSL is installed... " -NoNewLine
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        $status = $false
    }

    # Check if the Docker daemon is available
    Write-Host "Checking Docker daemon available... " -NoNewLine
    docker info 2>&1 | Out-Null
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
        [string]$distroName,
        [string]$distroUser
    )

    # Check for distro
    Write-Host "Checking distro '$distroName' present... " -NoNewLine
    $wslDistros = wsl --list --quiet
    if ($wslDistros -contains $distroName) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        if (-not $AutoInstall) {
            $confirmation = Read-Host "Create missing '$distroName' distro? (y/n)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "Please manually create the '$distroName' distro"
                return $false
            }
        }
        Write-Host "Creating distro '$distroName'... " -NoNewLine
        wsl --install ubuntu --name $distroName 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check if user is available
    Write-Host "Checking user '$distroUser' available in '$distroName' distro... " -NoNewLine
    wsl -d $distroName -e id -u $distroUser 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        if (-not $AutoInstall) {
            $confirmation = Read-Host "Create missing '$distroUser' user? (y/n)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "Please manually create the '$distroUser' user in $distroName distro"
                return $false
            }
        }
        Write-Host "Creating user '$distroUser' in '$distroName' distro... " -NoNewLine
        wsl -d $distroName -e bash -c "sudo adduser --disabled-password --gecos '' $distroUser" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            # provision the user, so that the ~/.docker/config.json can be created
            Start-Process wsl.exe -ArgumentList '-d', 'tyk-demo-ubuntu' -WindowStyle Hidden
            Write-Host "Done" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check for Docker config
    # Write-Host "Checking Docker config available... " -NoNewLine
    # $configFilePath = "~/.docker/config.json"
    # wsl -d $distroName -u $distroUser -e bash -c "test -f $configFilePath && grep 'cliPluginsExtraDirs' $configFilePath" 2>&1 | Out-Null
    # if ($LASTEXITCODE -eq 0) {
    #     Write-Host "Pass" -ForegroundColor Green
    # } else {
    #     Write-Host "Fail" -ForegroundColor Yellow
    #     if (-not $AutoInstall) {
    #         $confirmation = Read-Host "Config file? (y/n)"
    #         if ($confirmation -ne "y" -and $confirmation -ne "Y") {
    #             Write-Host "Please manually add a docker config file $configFilePath in '$distroName' distro"
    #             return $false
    #         }
    #     }

    #     wsl -d $distroName -u $distroUser -- bash -c 'mkdir -p ~/.docker && printf "{\"cliPluginsExtraDirs\":[\"/mnt/c/Program Files/Rancher Desktop/resources/resources/linux/docker-cli-plugins\"],\"credsStore\":\"wincred.exe\"}" > ~/.docker/config.json' 2>&1 | Out-Null
    #     if ($LASTEXITCODE -eq 0) {
    #         Write-Host "Done" -ForegroundColor Green
    #     } else {
    #         Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
    #         return $false
    #     }
    # }

    # Check for Docker in distro
    Write-Host "Checking Docker available in '$distroName' distro... " -NoNewLine
    wsl -d $distroName -u $distroUser -e bash -c "docker version" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        Write-Host "Please update WSL integration settings to provide Docker access to '$distroName' distro"
        return $false
    }

    # Check Docker Compose in distro
    Write-Host "Checking Docker Compose available in '$distroName' distro... " -NoNewLine
    wsl -d $distroName -u $distroUser -e bash -c "docker compose version" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Red
        Write-Host "Please update WSL integration settings to provide Docker access to '$distroName' distro"
        return $false
    }

    # Check for jq in distro
    Write-Host "Checking jq available in '$distroName' distro... " -NoNewLine
    wsl -d $distroName -u $distroUser -e jq --version 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        if (-not $AutoInstall) {
            $confirmation = Read-Host "Install jq in '$distroName' distro? (y/n)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "Please manually install jq in '$distroName' distro"
                return $false
            }
        }
        Write-Host "Installing jq in '$distroName' distro... " -NoNewLine
        wsl -d $distroName -u root -e bash -c "sudo apt-get update && sudo apt-get install -y jq" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check for websocat in distro
    Write-Host "Checking websocat available in '$distroName' distro... " -NoNewLine
    wsl -d $distroName -u $distroUser -e websocat --version 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        if (-not $AutoInstall) {
            $confirmation = Read-Host "Install websocat in '$distroName' distro? (y/n)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "Please manually install websocat in '$distroName' distro"
                return $false
            }
        }
        Write-Host "Installing websocat in '$distroName' distro... " -NoNewLine
        wsl -d $distroName -u root -e bash -c "curl -LO https://github.com/vi/websocat/releases/download/v1.14.0/websocat.x86_64-unknown-linux-musl && chmod +x websocat.x86_64-unknown-linux-musl && sudo mv websocat.x86_64-unknown-linux-musl /usr/local/bin/websocat" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done" -ForegroundColor Green
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
        [string]$distroUser,
        [string]$repoPath
    )

    # Check for Tyk Demo repo
    Write-Host "Checking Tyk Demo repository available at '$repoPath'... " -NoNewLine
    wsl -d $distroName -u $distroUser -e bash -c "test -d $repoPath" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        if (-not $AutoInstall) {
            $confirmation = Read-Host "Clone repo to '$repoPath'? (y/n)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "Please manually clone the repo to $repoPath in '$distroName' distro"
                return $false
            }
        }
        Write-Host "Cloning Tyk Demo repository to '$repoPath' in '$distroName' distro... " -NoNewLine
        # Create parent directory if needed
        $parentDir = Split-Path -Parent $repoPath
        wsl -d $distroName -u $distroUser -e bash -c "mkdir -p $parentDir" 2>&1 | Out-Null
        wsl -d $distroName -u $distroUser -e bash -c "git clone --branch windows --single-branch https://github.com/TykTechnologies/tyk-demo $repoPath"  2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Done" -ForegroundColor Green
        } else {
            Write-Host "Error (exit code $($LASTEXITCODE))" -ForegroundColor Red
            return $false
        }
    }

    # Check for Tyk licence
    Write-Host "Checking Tyk licence available... " -NoNewLine
    $envFilePath = "$repoPath/.env"
    wsl -d $distroName -u $distroUser -e bash -c "test -f $envFilePath && grep '^DASHBOARD_LICENCE=' $envFilePath" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pass" -ForegroundColor Green
    } else {
        Write-Host "Fail" -ForegroundColor Yellow
        if (-not $AutoInstall) {
            $confirmation = Read-Host "Add Tyk licence? (y/n)"
            if ($confirmation -ne "y" -and $confirmation -ne "Y") {
                Write-Host "Please manually add a Tyk licence to $envFilePath in '$distroName' distro"
                return $false
            }
        }
        $newLicence = Read-Host "Paste your Tyk licence and press enter"
        Write-Host "Adding licence... " -NoNewLine
        wsl -d $distroName --cd $repoPath -u $distroUser -e bash -c "./scripts/update-env.sh DASHBOARD_LICENCE $newLicence" 2>&1 | Out-Null
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

Write-Host "Tyk Demo Setup Configuration" -ForegroundColor Cyan
Write-Host "WSL Distro: $DistroName"
Write-Host "Repository Path: $RepoPath"
Write-Host "Distro User: $DistroUser"
Write-Host "Auto Install: $AutoInstall"

Write-Host "----------------------------------------"

Write-Host "Validating Host" -ForegroundColor Cyan
if (ValidateHost) {
    Write-Host "Host validation passed" -ForegroundColor Green
} else {
    Write-Host "Host validation failed" -ForegroundColor Red
    return
}

Write-Host "----------------------------------------"

Write-Host "Validating Distro" -ForegroundColor Cyan
if (ValidateDistro -distroName $DistroName -distroUser $DistroUser) {
    Write-Host "Distro validation passed" -ForegroundColor Green
} else {
    Write-Host "Distro validation failed" -ForegroundColor Red
    return
}

Write-Host "----------------------------------------"

Write-Host "Validating Repo" -ForegroundColor Cyan
if (ValidateRepo -distroName $DistroName -distroUser $DistroUser -repoPath $RepoPath) {
    Write-Host "Repo validation passed" -ForegroundColor Green
} else {
    Write-Host "Repo validation failed" -ForegroundColor Red
    return
}

Write-Host "----------------------------------------"

Write-Host "Validation process completed" -ForegroundColor Green