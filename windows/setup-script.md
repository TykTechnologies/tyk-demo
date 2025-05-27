# Tyk Demo Environment Setup Script (Simplified)

A PowerShell script designed for less-technical users to automatically set up the Tyk Demo environment on Windows using WSL (Windows Subsystem for Linux). This script handles all the complex setup steps for you.

> **Note**: This script is designed for ease-of-use and automation. If you're comfortable with command-line tools and prefer manual setup, or have an existing environment you want to use, please refer to the [standard readme](README.md).

## Prerequisites

- Windows 10/11 with WSL enabled
- Docker runtime (Docker Desktop, Rancher Desktop, or similar)
- Administrator privileges
- Internet connection for downloading dependencies
- Tyk licence

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DistroName` | String | `tyk-demo-ubuntu` | Name of the WSL distro to create/use |
| `RepoPath` | String | `~/tyk-demo` | Path where the Tyk Demo repository will be cloned |
| `DistroUser` | String | `tyk` | Username to create/use in the WSL distro |
| `AutoInstall` | Switch | `$false` | Skip confirmation prompts and auto-install missing components |

## Usage

### Basic Usage
```powershell
.\tyk-demo-setup.ps1
```

**Note:** Before running the script, make sure you have your Tyk licence ready to copy/paste - the script will prompt you for it.

### Custom Configuration
```powershell
.\tyk-demo-setup.ps1 -DistroName "my-tyk-env" -RepoPath "/home/user/tyk-demo" -DistroUser "admin"
```

### Automated Installation
```powershell
.\tyk-demo-setup.ps1 -AutoInstall
```

## What the Script Does

### Host Validation
- ✅ Verifies WSL is installed and available
- ✅ Checks Docker daemon accessibility
- ✅ Confirms administrator privileges

### Distro Validation
- 🔧 Creates WSL Ubuntu distro if missing
- 👤 Creates specified user account in the distro
- 🐳 Validates Docker access within the distro
- 🐳 Confirms Docker Compose availability
- 📦 Installs `jq` for JSON processing
- 🌐 Installs `websocat` for WebSocket testing

### Repository Setup
- 📂 Clones the Tyk Demo repository from GitHub
- 🔑 Prompts for and configures Tyk licence
- ⚙️ Sets up the `.env` file with licence configuration

## Interactive Prompts

When `AutoInstall` is not specified, the script will prompt for confirmation before:
- Creating a new WSL distro
- Creating a new user account
- Installing missing packages (`jq`, `websocat`)
- Cloning the repository
- Adding the Tyk licence

## Error Handling

The script provides clear feedback with color-coded output:
- 🟢 **Green**: Successful operations
- 🟡 **Yellow**: Warnings or missing components that can be fixed
- 🔴 **Red**: Critical errors that prevent continuation

If any validation step fails, the script will stop and provide guidance on how to resolve the issue manually.

## Output Example

```
Tyk Demo Setup Configuration
WSL Distro: tyk-demo-ubuntu
Repository Path: ~/tyk-demo
Distro User: tyk
Auto Install: False
----------------------------------------
Validating Host
Checking WSL is installed... Pass
Checking Docker daemon available... Pass
Host validation passed
----------------------------------------
Validating Distro
Checking Distro 'tyk-demo-ubuntu' present... Pass
Checking User 'tyk' available in 'tyk-demo-ubuntu' distro... Pass
Checking Docker available in 'tyk-demo-ubuntu' distro... Pass
Checking Docker Compose available in 'tyk-demo-ubuntu' distro... Pass
Checking jq available in 'tyk-demo-ubuntu' distro... Pass
Checking websocat available in 'tyk-demo-ubuntu' distro... Pass
Distro validation passed
----------------------------------------
Validating Repo
Checking Tyk Demo repository available at '~/tyk-demo'... Pass
Checking Tyk licence available... Pass
Repo validation passed
----------------------------------------
Validation process completed
```

## Troubleshooting

### Common Issues

**WSL not found**: Install WSL by running `wsl --install` in an administrator PowerShell session.

**Docker daemon not available**: Ensure your Docker runtime (Docker Desktop, Rancher Desktop, etc.) is running and WSL integration is enabled.

**Docker not accessible in distro**: Check your Docker runtime settings (Docker Desktop, Rancher Desktop, etc.) and enable WSL integration for your distro.

**Permission denied errors**: Ensure you're running PowerShell as administrator.

### Manual Setup

If the script fails at any point, you can manually perform the failed steps:

1. **Create WSL distro**: `wsl --install ubuntu --name tyk-demo-ubuntu`
2. **Create user**: `wsl -d tyk-demo-ubuntu -e sudo adduser tyk`
3. **Install jq**: `wsl -d tyk-demo-ubuntu -e sudo apt install jq`
4. **Install websocat**: Download from the [releases page](https://github.com/vi/websocat/releases)
5. **Clone repository**: `wsl -d tyk-demo-ubuntu -u tyk -e git clone https://github.com/TykTechnologies/tyk-demo`
