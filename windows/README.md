# Tyk Demo Windows Setup Guide

This guide outlines the technical process for setting up Tyk Demo on Windows for users who already have prerequisites installed and may wish to integrate Tyk Demo with existing environments.

## Setup Process Overview

The [included script](setup-tyk-demo.ps1) performs these key operations:

1. Prerequisite validation
2. WSL distro creation/validation
3. Repository cloning
4. License configuration
5. Docker-WSL integration check

The script is intended for users who may benefit from an automated approach to preparing their Tyk Demo environment.

## Manual Setup Steps

If you prefer manual setup or want to integrate with existing environments, follow these steps.

### Prerequisites

Required components:
- Docker Desktop with WSL2 backend
- Windows Subsystem for Linux (WSL2)
- A suitable WSL Linux distribution (Ubuntu recommended)
- Docker-WSL integration enabled for your target distro

### Installation Steps

#### 1. Prepare WSL Environment

**Option A: Use existing WSL distro**
- Ensure your existing distro has `git`, `jq` and `curl` installed:
  ```bash
  sudo apt update && sudo apt install -y git jq curl
  ```

**Option B: Create dedicated distro**
- Create a new WSL distro for Tyk (optional):
  ```powershell
  wsl --install ubuntu --name tyk-demo
  wsl -d tyk-demo -e bash -c "apt-get update && apt-get install -y jq"
  ```

**Note:** Ubuntu comes with `git` and `curl` pre-installed, so only `jq` needs installation.

#### 2. Clone Tyk Demo Repository

Inside your chosen WSL distro:
```bash
git clone https://github.com/TykTechnologies/tyk-demo /opt/tyk-demo
```

**Note:** You can clone to an alternative location, if you prefer. But these instructions will assume `/opt/tyk-demo`.

#### 3. Configure Tyk Licence

Create or update the `.env` file with your licence:
```bash
cd /opt/tyk-demo
./scripts/update-env.sh DASHBOARD_LICENCE your_licence_key_here
```

Replace `your_licence_key_here` with your actual Tyk licence.

The licence can also be modified directly in the `.env` file, by editing the line starting with `DASHBOARD_LICENCE`.

#### 4. Verify Docker Integration

Ensure Docker commands work within your WSL distro:
```bash
docker version
```

If this fails, enable integration in Docker Desktop:
- Settings → Resources → WSL Integration
- Enable for your distro

#### 5. Start Tyk Demo

```bash
cd /opt/tyk-demo
./up.sh
```

## Cleanup

Remove the current Tyk Demo deployment:
```bash
cd /opt/tyk-demo
./down.sh
```

This will remove all the docker resources (containers, volumes and networks) associated with Tyk Demo. The WSL distro will be unaffected.

## General Usage

Refer to the [standard Tyk Demo documentation](../README.md) for general usage. Once the Windows environment is correctly set up, you should be able to operate Tyk Demo using the stndard scripts and process.