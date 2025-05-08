# Windows Setup (PowerShell)

## Prerequisites

- Windows 10 version 2004 or higher / Windows 11
- Administrator privileges on your system

## Setup Instructions

1. **Open PowerShell as Administrator**:
   - Search for PowerShell in the Start menu
   - Right-click on Windows PowerShell and select "Run as administrator"
   - When asked for permission — click Yes

2. **Download and Run the Setup Script**:

   Copy and paste this into the PowerShell window:

   ```powershell
   curl.exe -s -L "https://raw.githubusercontent.com/TykTechnologies/tyk-demo/windows/windows/Setup-Tyk-Demo.ps1" -H "Cache-Control: no-cache" -o "$env:USERPROFILE\Downloads\Setup-Tyk-Demo.ps1"
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\Setup-Tyk-Demo.ps1"
   ```

   This will download and a script that prepares your system for Tyk Demo.


## What This Script Does

The script will automatically:

- Check for Docker Desktop and start it if not running
- Set up WSL 2 (Windows Subsystem for Linux) if not already installed
- Install Ubuntu distribution in WSL if not present
- Configure Docker Desktop WSL integration
- Clone and set up the Tyk Demo environment

## Troubleshooting

- **System Restart Required**: If prompted to restart after WSL installation, please do so and run the script again after reboot.
- **Docker Desktop WSL Integration**: Ensure WSL integration is enabled in Docker Desktop (Settings → Resources → WSL Integration).
- **Script Execution Issues**: If you encounter "execution of scripts is disabled on this system", use the execution policy command in step 2, which temporarily enables script execution only for your current PowerShell session.

## Manual Setup

If you prefer to install components manually:

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Install WSL 2 by running `wsl --install` in PowerShell as Administrator
3. Install Ubuntu from the Microsoft Store
4. Enable WSL integration in Docker Desktop settings
5. Clone the repository: `git clone https://github.com/TykTechnologies/tyk-demo.git`
6. Run the setup script: `cd tyk-demo && ./up.sh`