# Tyk Demo Setup Script
# This PowerShell script checks prerequisites and launches the Tyk demo in WSL
# Note: Run as administrator to ensure all operations can complete successfully
# Compatible with PowerShell 5.1 and newer

# Check for administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Please close this PowerShell window and re-run it using 'Run as Administrator'." -ForegroundColor Yellow
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}

# Display status messages
function Write-Status {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $color = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "ERROR"   = "Red"
        "WARNING" = "Yellow"
    }[$Type]
    $prefix = if ($Type -eq "INFO") { "==== $Message ====" } else { "[$Type] $Message" }
    Write-Host $prefix -ForegroundColor $color
}

# Check if a command exists - PS 5.1 compatible
function Test-CommandExists {
    param ([string]$Command)
    $cmdTest = Get-Command -Name $Command -ErrorAction SilentlyContinue
    return $null -ne $cmdTest
}

# Function to download and install Docker Desktop - PS 5.1 compatible
function Install-DockerDesktop {
    try {
        Write-Status "Docker Desktop is not installed. Attempting to download and install..." -Type "INFO"
        
        # Setup temporary directory for downloads
        $tempDir = Join-Path $env:TEMP "DockerInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        $installerPath = Join-Path $tempDir "DockerDesktopInstaller.exe"
        
        # Download Docker Desktop installer - PS 5.1 compatible approach
        Write-Status "Downloading Docker Desktop installer..." -Type "INFO"
        $dockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
        
        try {
            # Use .NET WebClient for PowerShell 5.1 compatibility
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($dockerUrl, $installerPath)
        }
        catch {
            Write-Status "Failed to download Docker Desktop: $($_.Exception.Message)" -Type "ERROR"
            return $false
        }
        
        if (Test-Path $installerPath) {
            Write-Status "Download completed. Installing Docker Desktop..." -Type "INFO"
            
            # Install Docker Desktop silently with explicit error handling
            try {
                $process = Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet" -Wait -PassThru -ErrorAction Stop
                $exitCode = $process.ExitCode
                
                if ($exitCode -eq 0) {                    
                    return $true
                } else {
                    return $false
                }
            }
            catch {
                Write-Status "Error during Docker Desktop installation: $($_.Exception.Message)" -Type "ERROR"
                return $false
            }
        } else {
            Write-Status "Failed to download Docker Desktop installer." -Type "ERROR"
            return $false
        }
    }
    catch {
        Write-Status "Error installing Docker Desktop: $($_.Exception.Message)" -Type "ERROR"
        return $false
    }
    finally {
        # Clean up temp files - with error handling
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    # Check for WSL first since Docker Desktop depends on it
    Write-Status "Checking WSL availability"
    $wslInstalled = $false
    
    # PS 5.1 compatible approach for command existence and output capture
    try {
        $wslOutput = ""
        $wslOutput = & wsl --status 2>&1
        # Convert to string if needed for PS 5.1
        if ($wslOutput -isnot [String]) {
            $wslOutput = $wslOutput | Out-String
        }
        
        # Check if the command was recognized
        if ($wslOutput -notlike "*is not recognized*" -and $wslOutput -notlike "*not found*") {
            $wslInstalled = $true
            Write-Status "WSL is available" -Type "SUCCESS"
        } else {
            Write-Status "WSL is not installed or not properly configured" -Type "WARNING"
        }
    }
    catch {
        Write-Status "WSL is not installed or not properly configured" -Type "WARNING"
        $wslInstalled = $false
    }

    # Check for Docker
    Write-Status "Checking for Docker CLI"
    $dockerInstalled = Test-CommandExists "docker"
    $dockerRunning = $false
    
    if ($dockerInstalled) {
        # Check if Docker is running - with explicit error handling for PS 5.1
        try {
            $dockerOutput = ""
            $dockerOutput = & docker info 2>&1
            
            # Convert to string if needed for PS 5.1
            if ($dockerOutput -isnot [String]) {
                $dockerOutput = $dockerOutput | Out-String
            }
            
            # Check for error patterns in output
            if ($dockerOutput -notlike "*Cannot connect to the Docker daemon*" -and 
                $dockerOutput -notlike "*error during connect*") {
                $dockerRunning = $true
                Write-Status "Docker is installed and responsive" -Type "SUCCESS"
            } else {
                Write-Status "Docker is installed but not running or not responsive." -Type "WARNING"
            }
        } catch {
            Write-Status "Docker is installed but not running or not responsive: $($_.Exception.Message)" -Type "WARNING"
        }
    } else {
        Write-Status "Docker is not installed." -Type "WARNING"
    }
    
    # Install in the correct order
    if (-not $wslInstalled -or -not $dockerInstalled) {
        # If Docker isn't installed, install it first since it might install WSL components
        if (-not $dockerInstalled) {
            Write-Status "Installing Docker Desktop first (will include WSL components)..." -Type "INFO"
            $installDocker = Install-DockerDesktop
            if (-not $installDocker) {
                Write-Status "Docker installation failed. Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop/" -Type "ERROR"
                exit 1
            }
            
            Write-Status "Docker Desktop has been installed. A system restart is required." -Type "WARNING"
            Write-Status "After restart, you'll need to complete the Docker Desktop first-time setup:" -Type "INFO"
            Write-Status "1. Accept the Docker T&Cs" -Type "INFO"
            Write-Status "2. Choose your Docker Desktop settings - select the default option" -Type "INFO"
            Write-Status "3. IMPORTANT: Setup will take several minutes as Docker installs and configures WSL" -Type "INFO"
            Write-Status "4. A Windows Subsystem for Linux (WSL) window may appear during the process - it can be closed" -Type "INFO"
            Write-Status "4. You'll know setup is complete when 'Starting the Docker Engine...' disappears" -Type "INFO"
            $restartChoice = Read-Host "Do you want to restart your computer now? (y/n)"
            if ($restartChoice -eq "y") {
                Restart-Computer -Force
            } else {
                Write-Status "Please restart your computer manually before continuing with Tyk setup." -Type "WARNING"
            }
            exit 0
        }
        
        # If only WSL is missing (rare case if Docker is installed without WSL)
        if (-not $wslInstalled -and $dockerInstalled) {
            Write-Status "WSL is not installed. Installing WSL..." -Type "WARNING"
            
            # Install WSL with compatibility check
            Write-Status "Installing WSL..." -Type "INFO"
            try {
                # Check PowerShell version to use appropriate WSL installation method
                $psVersion = $PSVersionTable.PSVersion.Major
                
                # Try the modern approach first with error handling
                try {
                    $wslInstallOutput = & wsl --install 2>&1
                    
                    # Convert to string if needed for PS 5.1
                    if ($wslInstallOutput -isnot [String]) {
                        $wslInstallOutput = $wslInstallOutput | Out-String
                    }
                    
                    # Check if the command was successful
                    if ($wslInstallOutput -like "*is not recognized*" -or $wslInstallOutput -like "*not found*") {
                        throw "Modern WSL install command not available"
                    }
                } catch {
                    # Fall back to manual installation for older Windows versions
                    Write-Status "Using alternative WSL installation method for compatibility..." -Type "INFO"
                    
                    # Enable WSL feature with explicit error handling
                    Write-Status "Enabling Windows Subsystem for Linux feature..." -Type "INFO"
                    try {
                        $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart" -Wait -PassThru -NoNewWindow
                        if ($process.ExitCode -ne 0) {
                            Write-Status "Failed to enable WSL feature. Exit code: $($process.ExitCode)" -Type "ERROR"
                        }
                    } catch {
                        Write-Status "Error enabling WSL feature: $($_.Exception.Message)" -Type "ERROR"
                    }
                    
                    # Enable Virtual Machine Platform feature (required for WSL 2)
                    Write-Status "Enabling Virtual Machine Platform feature..." -Type "INFO"
                    try {
                        $process = Start-Process -FilePath "dism.exe" -ArgumentList "/online /enable-feature /featurename:VirtualMachinePlatform /all /norestart" -Wait -PassThru -NoNewWindow
                        if ($process.ExitCode -ne 0) {
                            Write-Status "Failed to enable VM Platform feature. Exit code: $($process.ExitCode)" -Type "ERROR"
                        }
                    } catch {
                        Write-Status "Error enabling VM Platform feature: $($_.Exception.Message)" -Type "ERROR"
                    }
                }
                
                Write-Status "WSL installation initiated. A system restart is required." -Type "WARNING"
                Write-Status "After restart, run this script again to install Ubuntu." -Type "INFO"
                
            } catch {
                Write-Status "Error installing WSL: $($_.Exception.Message)" -Type "ERROR"
                Write-Status "Please install WSL manually. Visit https://docs.microsoft.com/en-us/windows/wsl/install for instructions." -Type "INFO"
            }
            
            $restartChoice = Read-Host "Do you want to restart your computer now? (y/n)"
            if ($restartChoice -eq "y") {
                Restart-Computer -Force
            } else {
                Write-Status "Please restart your computer manually before continuing with Tyk setup." -Type "WARNING"
            }
            exit 0
        }
    }
    
    # If Docker is installed but not running, try to start it
    if ($dockerInstalled -and -not $dockerRunning) {
        # Try to start Docker Desktop service
        Write-Status "Attempting to start Docker Desktop..." -Type "INFO"
        Write-Status "If Docker Desktop is starting for the first time, you may need to complete the setup wizard." -Type "INFO"
        Write-Status "This process can take several minutes, especially if installing WSL components." -Type "WARNING"
        Write-Status "Wait until the 'Starting the Docker Engine...' message disappears before proceeding." -Type "WARNING"
        
        # Check if Docker Desktop.exe exists in the default location
        $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        $dockerStarted = $false
        
        try {
            if (Test-Path $dockerDesktopPath) {
                Start-Process $dockerDesktopPath -ErrorAction SilentlyContinue
            } else {
                # Try alternative location for older Docker versions
                $altDockerPath = "${env:ProgramFiles}\Docker\Docker\Docker for Windows.exe"
                if (Test-Path $altDockerPath) {
                    Start-Process $altDockerPath -ErrorAction SilentlyContinue
                } else {
                    Write-Status "Could not find Docker Desktop executable. Please start Docker manually." -Type "WARNING"
                }
            }
            
            Write-Status "Waiting for Docker to start (up to 60 seconds)..." -Type "INFO"
            for ($i = 0; $i -lt 12; $i++) {
                Start-Sleep -Seconds 5
                try {
                    $dockerCheckOutput = & docker info 2>&1
                    
                    # Convert to string if needed
                    if ($dockerCheckOutput -isnot [String]) {
                        $dockerCheckOutput = $dockerCheckOutput | Out-String
                    }
                    
                    if ($dockerCheckOutput -notlike "*Cannot connect to the Docker daemon*" -and 
                        $dockerCheckOutput -notlike "*error during connect*") {
                        $dockerStarted = $true
                        break
                    }
                } catch {
                    # Continue trying
                }
            }
        } catch {
            Write-Status "Error starting Docker Desktop: $($_.Exception.Message)" -Type "ERROR"
        }
        
        if (-not $dockerStarted) {
            Write-Status "Docker Desktop failed to start. Please start Docker Desktop manually and run this script again." -Type "ERROR"
            exit 1
        }
        Write-Status "Docker is now running" -Type "SUCCESS"
    }
    
    # Second WSL check after possible installations
    Write-Status "Verifying WSL availability"
    try {
        $wslVerifyOutput = & wsl --status 2>&1
        
        # Convert to string if needed
        if ($wslVerifyOutput -isnot [String]) {
            $wslVerifyOutput = $wslVerifyOutput | Out-String
        }
        
        if ($wslVerifyOutput -like "*is not recognized*" -or $wslVerifyOutput -like "*not found*") {
            Write-Status "WSL is still not properly configured. This may require manual troubleshooting." -Type "ERROR"
            exit 1
        }
        Write-Status "WSL is properly configured" -Type "SUCCESS"
    } catch {
        Write-Status "WSL verification failed: $($_.Exception.Message)" -Type "ERROR"
        exit 1
    }

    # Check for Ubuntu using a PS 5.1 compatible approach
    Write-Status "Checking for Ubuntu distro"
    $ubuntuInstalled = $false
    
    try {
        $wslOutput = wsl -l -v | Out-String

        # Process each line:
        # 1. Remove null characters (U+0000). This step is harmless if no null characters exist.
        # 2. Normalize all sequences of whitespace characters into a single standard space.
        # 3. Pipe the cleaned lines to Where-Object to find any line matching "ubuntu" (case-insensitive).
        #    We pipe directly to Where-Object to stop processing as soon as a match is found, for efficiency.
        $isUbuntuFound = $wslOutput | ForEach-Object {
            $_ -replace [char]0x0000, '' -replace '\s+', ' '
        } | Where-Object {
            $_ -match "ubuntu" # -match is case-insensitive by default
        }
        
        $ubuntuInstalled = [bool]$isUbuntuFound
    } catch {
        $ubuntuInstalled = $false
        Write-Status "Error checking for Ubuntu: $($_.Exception.Message)" -Type "WARNING"
    }
    
    if (-not $ubuntuInstalled) {
        Write-Status "Ubuntu is not installed. Installing Ubuntu..." -Type "WARNING"
        
        # Try different approaches for compatibility
        try {
            # Modern approach with error handling
            Write-Status "Installing Ubuntu on WSL..." -Type "INFO"
            $ubuntuInstallOutput = & wsl --install -d Ubuntu 2>&1
            
            # Convert to string if needed
            if ($ubuntuInstallOutput -isnot [String]) {
                $ubuntuInstallOutput = $ubuntuInstallOutput | Out-String
            }
            
            # Check if command was recognized
            if ($ubuntuInstallOutput -like "*is not recognized*" -or $ubuntuInstallOutput -like "*not found*") {
                # Fall back to alternative method for older systems
                Write-Status "Using alternative Ubuntu installation method..." -Type "INFO"
                
                # Direct users to Microsoft Store (manual approach)
                Write-Status "Please install Ubuntu from the Microsoft Store:" -Type "WARNING"
                Write-Status "1. Open Microsoft Store" -Type "INFO"
                Write-Status "2. Search for 'Ubuntu'" -Type "INFO"
                Write-Status "3. Install and run Ubuntu to complete setup" -Type "INFO"
                Write-Status "4. Run this script again after Ubuntu is configured" -Type "INFO"
                
                # Try to open Microsoft Store for them
                try {
                    Start-Process "ms-windows-store://search/?query=Ubuntu"
                } catch {
                    Write-Status "Could not open Microsoft Store. Please open it manually." -Type "WARNING"
                }
                exit 0
            }
        } catch {
            Write-Status "Error installing Ubuntu: $($_.Exception.Message)" -Type "ERROR"
            Write-Status "Please install Ubuntu manually from the Microsoft Store." -Type "INFO"
            exit 1
        }
        
        Write-Status "Ubuntu installation completed. You'll need to configure it on first run." -Type "SUCCESS"
        Write-Status "The Ubuntu setup will start in a new window. Please complete the setup there." -Type "INFO"
        Write-Status "After configuration, please run this script again." -Type "INFO"
        
        # Launch Ubuntu to complete setup (with error handling)
        try {
            Start-Process "wsl.exe" -ArgumentList "-d", "Ubuntu" -ErrorAction SilentlyContinue
        } catch {
            Write-Status "Could not automatically launch Ubuntu. Please launch it manually to complete setup." -Type "WARNING"
        }
        exit 0
    }
    Write-Status "Ubuntu is installed" -Type "SUCCESS"

    # Set Ubuntu as default with error handling for PS 5.1
    try {
        $defaultOutput = & wsl --set-default Ubuntu 2>&1
        
        # Convert to string if needed
        if ($defaultOutput -isnot [String]) {
            $defaultOutput = $defaultOutput | Out-String
        }
        
        if ($defaultOutput -like "*error*" -or $defaultOutput -like "*is not recognized*") {
            Write-Status "Could not set Ubuntu as default WSL distro using modern command." -Type "WARNING"
            # Try alternative approach for older systems
            $wslConfigPath = "$env:USERPROFILE\.wslconfig"
            "[wsl2]`ndefaultDistribution=Ubuntu" | Out-File -FilePath $wslConfigPath -Encoding ASCII -Force
            Write-Status "Attempted to set Ubuntu as default using .wslconfig file" -Type "INFO"
        } else {
            Write-Status "Set Ubuntu as default WSL distro" -Type "SUCCESS"
        }
    } catch {
        Write-Status "Failed to set Ubuntu as default WSL distro: $($_.Exception.Message)" -Type "WARNING"
        # This is not critical, so we'll continue
    }

    # Check Docker integration inside WSL with explicit error handling
    Write-Status "Checking Docker inside Ubuntu"
    $dockerInWsl = $false
    
    try {
        # Capture and suppress stderr to avoid error output to console in PS 5.1
        $dockerCheckWsl = & wsl -d Ubuntu -- which docker 2>$null
        $dockerInWsl = $null -ne $dockerCheckWsl -and $dockerCheckWsl -ne ""
    } catch {
        $dockerInWsl = $false
    }
    
    if (-not $dockerInWsl) {
        Write-Status "Docker is not available in WSL." -Type "WARNING"
        Write-Status "Checking Docker Desktop WSL integration setting..." -Type "INFO"
        
        # Prompt user to enable integration
        Write-Status "Please enable Docker Desktop WSL integration:" -Type "WARNING"
        Write-Status "1. Open Docker Desktop" -Type "INFO"
        Write-Status "2. Go to Settings → Resources → WSL Integration" -Type "INFO"
        Write-Status "3. Enable integration for Ubuntu" -Type "INFO"
        Write-Status "4. Click Apply & Restart" -Type "INFO"
        
        $dockerChoice = Read-Host "Press Enter once you've enabled Docker WSL integration"
        
        # Check again with explicit error handling
        try {
            $dockerCheckWsl = & wsl -d Ubuntu -- which docker 2>$null
            $dockerInWsl = $null -ne $dockerCheckWsl -and $dockerCheckWsl -ne ""
        } catch {
            $dockerInWsl = $false
        }
        
        if (-not $dockerInWsl) {
            Write-Status "Docker is still not available in WSL. Please ensure Docker Desktop WSL integration is enabled for Ubuntu." -Type "ERROR"
            Write-Status "NOTE: You may need to wait for Docker Desktop's initial setup to fully complete first." -Type "WARNING"
            Write-Status "The setup is complete when the 'Setting up Docker Engine...' message disappears." -Type "INFO"
            exit 1
        }
    }
    Write-Status "Docker is available inside WSL" -Type "SUCCESS"

    # Update packages with explicit error handling
    Write-Status "Updating packages in Ubuntu"
    $updateFailed = $false
    
    try {
        # Capture command output
        $updateOutput = & wsl -d Ubuntu -- bash -c "sudo apt-get update -qq && sudo apt-get install -y -qq git jq curl" 2>&1
        
        # Check for errors
        if ($LASTEXITCODE -ne 0) {
            $updateFailed = $true
            Write-Status "APT command failed with exit code: $LASTEXITCODE" -Type "ERROR"
        }
    } catch {
        $updateFailed = $true
        Write-Status "Error updating packages: $($_.Exception.Message)" -Type "ERROR"
    }
    
    if ($updateFailed) {
        Write-Status "Failed to update packages in Ubuntu" -Type "ERROR"
        exit 1
    }
    Write-Status "Packages updated successfully" -Type "SUCCESS"

    # Check Docker Compose with explicit error handling
    Write-Status "Checking Docker Compose in Ubuntu"
    $dockerComposeAvailable = $false
    
    try {
        $dockerComposeOutput = & wsl -d Ubuntu -- bash -c "docker compose version > /dev/null 2>&1 || (echo 'Docker Compose not available' && exit 1)" 2>&1
        $dockerComposeAvailable = $LASTEXITCODE -eq 0
    } catch {
        $dockerComposeAvailable = $false
        Write-Status "Error checking Docker Compose: $($_.Exception.Message)" -Type "ERROR"
    }
    
    if (-not $dockerComposeAvailable) {
        Write-Status "Docker Compose not available in Ubuntu. Enable Docker integration in WSL settings." -Type "ERROR"
        exit 1
    }
    Write-Status "Docker Compose is available in Ubuntu" -Type "SUCCESS"

    # Clone or update Tyk demo repository with explicit error handling
    Write-Status "Setting up Tyk demo repository"
    $repoSetupFailed = $false
    
    try {
        $repoSetupOutput = & wsl -d Ubuntu -- bash -c "if [ -d ~/tyk-demo ]; then echo 'Updating existing repository'; cd ~/tyk-demo && git pull; else echo 'Cloning repository'; git clone https://github.com/TykTechnologies/tyk-demo.git ~/tyk-demo; fi" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $repoSetupFailed = $true
            Write-Status "Git command failed with exit code: $LASTEXITCODE" -Type "ERROR"
        }
    } catch {
        $repoSetupFailed = $true
        Write-Status "Error setting up repository: $($_.Exception.Message)" -Type "ERROR"
    }
    
    if ($repoSetupFailed) {
        Write-Status "Failed to setup Tyk demo repository" -Type "ERROR"
        exit 1
    }
    Write-Status "Tyk demo repository setup completed" -Type "SUCCESS"
    
            # Launch Tyk Demo
    Write-Status "Ready to launch Tyk demo" -Type "SUCCESS"
    Write-Status "Make sure Docker Desktop is properly configured with WSL Integration enabled for Ubuntu" -Type "INFO"
    Write-Status "To verify, check Docker Desktop → Settings → Resources → WSL Integration" -Type "INFO"
    Write-Status "To start the demo, run the following command in WSL:" -Type "INFO"
    Write-Status "cd ~/tyk-demo && ./up.sh" -Type "INFO"

    Read-Host -Prompt "Press Enter to exit"
}
catch {
    Write-Status "An unexpected error occurred: $_" -Type "ERROR"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit 1
}