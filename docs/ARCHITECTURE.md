# Tyk Demo Architecture

This document provides detailed information about the Tyk Demo architecture and its components.

## Deployment Structure

Tyk Demo implements a modular architecture with two types of deployments:

1. **Base Deployment** (mandatory)
   - Located in `deployments/tyk` directory
   - Provides standard Tyk components (Gateway, Dashboard, Pump)
   - Includes supporting databases (Redis and MongoDB)
   - Implements a wide range of Tyk features and functionality
   - Serves as the foundation for all feature deployments

2. **Feature Deployments** (optional)
   - Extend the base deployment functionality
   - Focus on specific Tyk capabilities or use cases
   - Located in separate directories under `deployments/`
   - Require the base deployment to function correctly

## Repository Structure

```
tyk-demo/
├── deployments/                  # All available deployments
│   ├── tyk/                      # Base deployment
│   ├── analytics-kibana/         # Feature deployment example
│   ├── cicd/                     # Feature deployment example
│   └── ...                       # Other feature deployments
├── docs/                         # General documentation
├── scripts/                      # Utility scripts
├── docker-compose-command.sh     # Helper for Docker Compose commands
├── down.sh                       # Deployment removal script
├── README.md                     # Main documentation
└── up.sh                         # Deployment creation script
```

### Deployment Directory Structure

Each deployment directory contains:

| File/Directory                          | Description                              | Required |
|-----------------------------------------|------------------------------------------|----------|
| `bootstrap.sh`                          | Initialization script                    | Yes      |
| `deployment.json`                       | Information manifest                     | No       |
| `docker-compose.yml`                    | Container configuration                  | Yes      |
| `README.md`                             | Documentation                            | No       |
| `data/` or `volumes/`                   | Data and volume mappings                 | No       |
| `scripts/`                              | Utility scripts                          | No       |
| `scripts/examples/`                     | Script-based examples                    | No       |
| `teardown.sh`                           | Removes assets outside of Docker Compose control | No |
| `tyk_demo_<deployment>.postman_collection.json` | Postman-based examples and tests | No       |

## Component Architecture

### Base Deployment Components

The base deployment includes:

- **Tyk Gateway**: API Gateway responsible for managing traffic
- **Tyk Dashboard**: Web interface for managing APIs, policies, and users
- **Tyk Pump**: Analytics processor that moves data between Redis and MongoDB
- **Redis**: Primary database for the Tyk Gateway
- **MongoDB**: Primary database for the Tyk Dashboard

### Feature Deployment Integration

Feature deployments integrate with the base deployment by:

1. Extending the base Docker Compose deployment with additional containers
2. Configuring integration points with the base deployment
3. Running bootstrap scripts to prepare the deployment
4. Displaying deployment-specific information

## Bootstrap Process

When executing the `up.sh` script, the following process occurs:

1. Determine which deployments to create/resume
2. Launch all required containers with Docker Compose
3. Execute the bootstrap scripts for each deployment
4. Record deployments in `.bootstrap/bootstrapped_deployments`

The bootstrap scripts handle all the actions necessary in order to prepare the deployment for usage:
- Configures environment variables
- Prepares services
- Generates assets
- Imports data
- Validates system state
- Displays system information

Progress is logged to the `logs/bootstrap.log` file.

## Environment Configuration

Tyk Demo uses Docker environment variables (stored in `.env`) to configure the deployment. These variables allow for customization without modifying the source configuration files.

Many of the other variables are automatically set by the scripts. If a deployment requires manually set environment variables, the relevant instructions will be contained in its readme.

## Network Configuration

All containers run within a Tyk Demo Docker network called `tyk-demo_tyk`. This enables cross-container access.

Some containers have ports mapped to the host, enabling the services within them to be accessed.

Some services and APIs use custom hostnames, which are added to the `/etc/hosts` file via the `scripts/update-hosts.sh` script. This is covered as part of the "getting started" process.
