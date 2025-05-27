# Tyk Demo Windows Environment Setup

## Overview

This document outlines the manual setup steps for preparing a Tyk Demo environment on Windows using WSL. While the [automated PowerShell script](setup-tyk-demo-env.ps1) is available for non-technical users, this guide provides the individual validation and setup steps for technical users who may already have existing WSL configurations or prefer manual control over the setup process.

## Prerequisites

### Host System Requirements

1. **WSL Installation**: Ensure WSL is installed and functional
   ```bash
   wsl --version
   ```

   If not already installed, run
   ```bash
   wsl --install
   ```

2. **Docker Engine**: Docker daemon must be running and accessible (Docker Desktop, Rancher Desktop, or other Docker-compatible runtime)
   ```bash
   docker info
   ```

3. **Administrator Privileges**: Required for certain operations (distro creation, package installation)

## Environment Configuration

### Default Values
- **WSL Distro Name**: `tyk-demo-ubuntu`
- **Repository Path**: `~/tyk-demo`
- **Distro User**: `tyk`

These values will be used in the examples below, but can be changed to meet the needs of your environment.

## Setup Components

### 1. WSL Distro Setup

It is recommended to use an Ubuntu distro to host the Tyk Demo repository.

If you don't have an existing distro, you can create a new one:
```bash
wsl --install ubuntu --name tyk-demo-ubuntu
```

### 2. Docker Integration

The distro must be able to access the Docker socket and tools installed on your host.

You can verify access by attempting to run docker commands within the distro:
#### Verify Docker Access in WSL
```bash
wsl -d tyk-demo-ubuntu -e docker version
```

#### Verify Docker Compose
```bash
wsl -d tyk-demo-ubuntu -e docker compose version
```

Both Docker and Docker Compose are needed.

If Docker is not accessible, enable WSL integration in your Docker runtime settings (Docker Desktop, Rancher Desktop, etc.) for your target distro.

### 3. Required Tools Installation

#### Install jq

`jq` is mandatory. It is required to run the Tyk Demo bootstrap script:
```bash
wsl -d tyk-demo-ubuntu -u root -e bash -c "apt-get update && apt-get install -y jq"
```

#### Install websocat

`websocat` is optional. It is only required to run some streaming API examples:
```bash
wsl -d tyk-demo-ubuntu -u root -e bash -c "
curl -LO https://github.com/vi/websocat/releases/download/v1.14.0/websocat.x86_64-unknown-linux-musl && 
chmod +x websocat.x86_64-unknown-linux-musl && 
mv websocat.x86_64-unknown-linux-musl /usr/local/bin/websocat"
```

### 4. Repository Setup

#### Clone Tyk Demo Repository
```bash
wsl -d tyk-demo-ubuntu -u tyk -e bash -c "git clone https://github.com/TykTechnologies/tyk-demo ~/tyk-demo"
```

#### Configure Tyk Licence
1. Obtain your Tyk licence key
2. Update the environment configuration:
```bash
wsl -d tyk-demo-ubuntu -u tyk -e bash -c "
cd ~/tyk-demo && 
./scripts/update-env.sh DASHBOARD_LICENCE YOUR_LICENCE_KEY_HERE"
```

### 5. Ready for Use

Tyk Demo is now ready for use.

For more information, please refer to the [main readme](../README.md) and [tyk deployment readme](../deployments/tyk/README.md).

#### Starting Tyk Demo

This command will bring the Tyk Demo environment up:
```bash
wsl -d tyk-demo-ubuntu -u tyk --cd ~/tyk-demo -e bash -c "./up.sh --skip-hostname-check"
```

**Note:** The `--skip-hostname-check` flag is used as this WSL-based approach does not require hostnames to be checked within the distro.

#### Stopping Tyk Demo

This command will tear the Tyk Demo environment down:
```bash
wsl -d tyk-demo-ubuntu -u tyk --cd ~/tyk-demo -e bash -c "./down.sh"
```

## Validation Steps

### Host Validation
```bash
# Check WSL availability
wsl --version

# Check Docker daemon
docker info
```

### Distro Validation
```bash
# Verify distro exists
wsl --list | grep tyk-demo-ubuntu

# Verify user exists
wsl -d tyk-demo-ubuntu -e id -u tyk

# Verify Docker access
wsl -d tyk-demo-ubuntu -e docker version
wsl -d tyk-demo-ubuntu -e docker compose version

# Verify tools
wsl -d tyk-demo-ubuntu -e jq --version
wsl -d tyk-demo-ubuntu -e websocat --version
```

### Repository Validation
```bash
# Verify repository exists
wsl -d tyk-demo-ubuntu -u tyk -e bash -c "test -d ~/tyk-demo && echo 'Repository found'"

# Verify license configuration
wsl -d tyk-demo-ubuntu -u tyk -e bash -c "grep '^DASHBOARD_LICENCE=' ~/tyk-demo/.env"
```

## Troubleshooting

### Common Issues

1. **Docker not accessible in WSL**
   - Enable WSL integration in your Docker runtime settings (Docker Desktop, Rancher Desktop, etc.)
   - Restart your Docker runtime after enabling integration

2. **Permission denied errors**
   - Ensure you're running commands with appropriate user privileges
   - Use `-u root` for system-level operations when needed

3. **Network issues during package installation**
   - Verify internet connectivity within WSL
   - Update package repositories: `apt-get update`

4. **Git clone failures**
   - Check network connectivity
   - Verify Git is installed in the WSL distro

## Alternative Configurations

### Using Existing WSL Distro
If you prefer to use an existing WSL distro instead of creating a new one:

1. Replace `tyk-demo-ubuntu` with your existing distro name in all commands
2. Ensure your existing user has appropriate permissions
3. Install missing tools as needed

### Custom Repository Location
To use a different repository location:

1. Replace `~/tyk-demo` with your preferred path
2. Ensure the parent directory exists and is writable by your user
3. Update any relative path references accordingly

## Security Considerations

- The setup process requires administrator privileges for certain operations

## Next Steps

After completing the setup:

1. Navigate to the repository directory within your WSL distro
2. Follow the Tyk Demo documentation for starting and configuring the environment
3. Verify all services are running correctly using the provided scripts
4. Configure any additional integrations or customizations as needed