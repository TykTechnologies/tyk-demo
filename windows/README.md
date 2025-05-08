# Windows Setup (PowerShell)

## Prerequisites

- Windows 10 version 2004 or higher / Windows 11
- Administrator privileges on your system

## Setup Instructions

1. **Open PowerShell as Administrator**:
   - Search for PowerShell in the Start menu
   - Right-click on Windows PowerShell and select "Run as Administrator"

2. **Set PowerShell Execution Policy** (if you haven't run PowerShell scripts before):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Download and Run the Setup Script**:
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/TykTechnologies/tyk-demo/windows/windows/Setup-TykDemo.ps1" -OutFile "$env:USERPROFILE\Downloads\Setup-TykDemo.ps1"
   & "$env:USERPROFILE\Downloads\Setup-TykDemo.ps1"
   ```

## What This Script Does

The script will automatically:

- Check for and guide you through installing Docker Desktop if needed
- Set up WSL 2 (Windows Subsystem for Linux) if not already installed
- Install Ubuntu distribution in WSL if not present
- Configure Docker Desktop WSL integration
- Clone and set up the Tyk Demo environment

## Troubleshooting

- **System Restart Required**: If prompted to restart after WSL installation, please do so and run the script again after reboot.
- **Docker Desktop WSL Integration**: Ensure WSL integration is enabled in Docker Desktop (Settings → Resources → WSL Integration).
- **Script Execution Issues**: If you encounter "execution of scripts is disabled on this system", make sure to run the execution policy command in step 2.

## Manual Setup

If you prefer to install components manually:

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Install WSL 2 by running `wsl --install` in PowerShell as Administrator
3. Install Ubuntu from the Microsoft Store
4. Enable WSL integration in Docker Desktop settings
5. Clone the repository: `git clone https://github.com/TykTechnologies/tyk-demo.git`
6. Run the setup script: `cd tyk-demo && ./up.sh`