# Tyk Demo

[![Tyk Demo Tests](https://github.com/TykTechnologies/tyk-demo/actions/workflows/tyk-demo-tests.yml/badge.svg)](https://github.com/TykTechnologies/tyk-demo/actions/workflows/tyk-demo-tests.yml)

A ready-to-run sandbox for exploring Tyk's API management platform through practical, hands-on use.

## What is Tyk Demo?

Tyk Demo provides:
- Pre-configured deployments showcasing various Tyk capabilities
- Automated setup and bootstrapping
- Postman collections and scripts for interactive exploration
- A modular structure for mixing and matching features of interest

While created primarily for Tyk's technical staff, anyone interested in exploring Tyk functionality can benefit from this sandbox environment.

> **Note:** This repository was developed and tested on macOS using Docker. The instructions provided are tailored for this setup. Users on other operating systems may encounter differences and should adapt accordingly. There is a separate [Windows readme](windows/README.md) that provides guidance on preparing Tyk Demo to run on that platform.

## Getting Started

### Prerequisites

- Docker with Docker Compose
  - Recommended 4GB RAM allocated for container resources
- `jq` command-line utility
- A valid Tyk license

### Quick Start

**1. Clone the repository**

```bash
git clone https://github.com/TykTechnologies/tyk-demo.git
cd tyk-demo
```

**2. Configure local DNS entries**

```bash
sudo ./scripts/update-hosts.sh
```

This script updates your system's hosts file to map custom domain names (like tyk-dashboard.localhost) to your local machine. These are used to help identify the different Tyk services and APIs.

> **Note:** You'll be prompted for your password because modifying the hosts file requires administrator privileges.

**3. Add your licence**

Use this command to apply your Tyk licence, replacing `YOUR_LICENCE_KEY` with your actual licence key:

```bash
./scripts/update-env.sh DASHBOARD_LICENCE YOUR_LICENCE_KEY
```

The command takes two parameters:
- `DASHBOARD_LICENCE`: This is the environment variable name (don't change this)
- `YOUR_LICENCE_KEY`: Replace this with your actual Tyk licence key

If you also have a licence for MDCB, that can also be added:

```bash
./scripts/update-env.sh MDCB_LICENCE YOUR_MDCB_LICENCE_KEY
```

**4. Launch the environment**

```bash
./up.sh
```

Wait until you see the message "Tyk Demo initialisation process completed". The environment details, including usernames, passwords, and API keys will be shown at this point.

> **Note:** On the first run, Go plugins will be built automatically. This can take 5–10 minutes or longer, depending on your system's performance. This build is cached for future runs, so subsequent launches will be much faster. If needed, you can skip this step with the `--skip-plugin-build` flag, though this might affect functionality that depends on Go plugins.

**5. Access the Tyk dashboard**

Use the credentials shown in the output to log in to the [Tyk Dashboard](http://tyk-dashboard.localhost:3000).

**6. Import the Postman collection**

Import the [Tyk Demo Postman collection](deployments/tyk/tyk_demo_tyk.postman_collection.json) into [Postman](https://www.postman.com/) to start exploring Tyk's functionality.

## Architecture

Tyk Demo uses a modular approach:

- **Base deployment**: Core Tyk components (Gateway, Dashboard, Pump) with supporting databases
- **Feature deployments**: Optional extensions (analytics, SSO, observability etc.)

For architecture details, see the [Architecture Guide](docs/architecture.md).

## Feature Deployments

Tyk Demo uses a modular architecture that allows you to add optional feature deployments to extend the base functionality. Each feature deployment focuses on a specific Tyk capability or integration scenario.

To add a feature deployment:

```bash
./up.sh feature-deployment-name
```

Example:
```bash
./up.sh analytics-kibana
```

For a complete list of all available feature deployments and their descriptions, see the [Feature Deployments Guide](docs/feature-deployments.md).

## Common Operations

### Add Feature Deployments

```bash
./up.sh analytics-kibana instrumentation
```

### Stop and Remove

```bash
./down.sh
```

### Resume a Paused Deployment

```bash
./up.sh
```

For more operations, see the [Operations Guide](docs/operations.md).

## Troubleshooting

Check the [Troubleshooting Guide](docs/troubleshooting.md) for solutions to common issues.

## Contributing

Contributions are welcome. See the [Contributor Guide](CONTRIBUTING.md) for more information.