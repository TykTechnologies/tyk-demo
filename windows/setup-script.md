# Tyk Demo for Windows - Setup Script

This guide helps Windows users set up their environment to run Tyk Demo, which is originally built for MacOS but can run on Windows with proper configuration.

## Overview

The included [PowerShell script](setup-tyk-demo.ps1) automates the process of preparing your Windows environment to run Tyk Demo. It performs prerequisite checks, sets up the necessary components, and ensures everything is properly configured.

**Note:** The PowerShell script only prepares the Tyk Demo environment, it does not bootstrap Tyk Demo - this is still performed by the standard Tyk Demo scripts within the repo.

## Prerequisites

Before running the setup script, you'll need:

- Windows 10 or 11
- Administrator access on your machine
- Internet connection

## Components Installed/Configured

The script will check for and help set up:

1. **Docker Desktop** - Container platform required to run Tyk services
2. **Windows Subsystem for Linux (WSL)** - Enables running Linux environments on Windows
3. **Ubuntu WSL Distro** - A dedicated Linux distribution for Tyk Demo
4. **Tyk Demo Repository** - The actual demo environment code
5. **Docker in WSL Integration** - Allows Docker commands to run within WSL

If you do not require this level of assistance with setting up the environment (e.g. you already have Docker and WSL installed, and have a pre-existing distro available), then you can find general instructions in the [windows README](README.md).

## Installation Instructions

### Step 1: Install Prerequisites (if not already installed)

Before running the script, ensure you have:

- **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop/)
- **WSL** - Run `wsl --install` in PowerShell as administrator

### Step 2: Prepare Your Tyk License

The setup script will prompt you for your Tyk license. Have your license key ready to paste when prompted.

### Step 3: Run the Setup Script

1. Open PowerShell as Administrator
2. Navigate to the directory containing the script
3. Execute the script:
   ```powershell
   .\setup-tyk-demo.ps1
   ```

### Step 4: Follow the Prompts

The script will:
- Check if all prerequisites are installed
- Verify if the Tyk Demo WSL distro exists (or create it)
- Clone the Tyk Demo repository (if needed)
- Prompt for your Tyk license (if not already configured)
- Verify Docker integration with WSL

## Starting Tyk Demo

After the setup script completes successfully:

1. Open PowerShell or Command Prompt
2. Start Tyk Demo with:
   ```
   wsl -d tyk-demo
   cd /opt/tyk-demo
   ./up.sh
   ```
3. Once started, you can access:
   - Tyk Dashboard: http://tyk-dashboard.localhost:3000
   - Login details are displayed in the output of the `up.sh` script

**Note:** On first usage, you will be prompted to create a user account in the `tyk-demo` distro.

## Troubleshooting

### Docker Desktop WSL Integration

If the script shows "Docker is not available in Tyk Demo distro":
1. Open Docker Desktop
2. Go to Settings → Resources → WSL Integration
3. Enable integration with the "tyk-demo" distro
4. Apply changes and restart Docker Desktop

### WSL Issues

If you encounter WSL-related errors:
1. Ensure WSL is properly installed: `wsl --status`
2. Try updating WSL: `wsl --update`
3. If problems persist, try restarting your computer

### License Issues

If your license isn't being recognized, try setting the necessary environment variable:
1. In WSL, navigate to `/opt/tyk-demo`
2. Run `./scripts/update-env.sh DASHBOARD_LICENCE your_license_key`

## Stopping Tyk Demo

To stop the demo environment:
1. In WSL Tyk Demo distro: `cd /opt/tyk-demo && ./down.sh`

## Additional Resources

- [Tyk Documentation](https://tyk.io/docs/)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
- [Docker Desktop Documentation](https://docs.docker.com/desktop/)