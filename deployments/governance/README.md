# Tyk Governance

> ⚠️ **Note:** This is a preview of the Tyk Governance product. It is still under development.

This deployment demonstrates how Tyk Governance can be used to validate API specifications against defined rulesets.

## Components

The deployment includes:

- **Tyk Governance Dashboard** – A user interface for reviewing API compliance.
- **Tyk Governance Agent** – A service that synchronises API definitions.

The system is automatically configured during the bootstrap process and is ready to use out of the box. The Agent comes preconfigured with a `tyk` provider, which pulls OAS-based API definitions from the Tyk Dashboard.

Once bootstrapped, access the Governance Dashboard at:

- **URL:** http://tyk-governance-dashboard.localhost:8082  
- **Username:** `govn.user@example.com`  
- **Password:** `m8YEVG4L`

## Setup

### Licence

A valid licence is required for both the Governance Dashboard and Agent. Add it to the `.env` file using the following variable:

```env
GOVERNANCE_LICENSE=<YOUR_LICENSE_HERE>
```

### Prerequisites

`yq` is required by the bootstrap script.

It can be installed on MacOS using the Brew package manager:

```bash
brew install yq
```

### Bootstrap

Run the this command to deploy Tyk Demo with Governance:

```bash
./up.sh governance
```

### Files

There are several files used to configure the deployment during bootstrap:

- [Governance Agent Config](deployments/governance/data/governance-agent/config.yaml): Configures the Agent. It is copied to the mapped `volume` directory, where it is then updated with the configuration necessary for the Agent to authenticate with both the Governance and standard Tyk Dashboards.
- [Governance Dashboard Bootstrap](deployments/governance/data/governance-dashboard/bootstrap.json): Defines the users used to bootstrap the Governance Dashboard. This user's API token is then used to interact with the dashboard during the bootstrap process.
- [Governance Agent Definition](deployments/governance/data/governance-dashboard/agent.json): Defines the Governance Agent definition in the dashboard. This is only the name, the actual agent configuration comes from the *Governance Agent Config* listed above.
- [Governance Dashboard Agent User](deployments/governance/data/governance-dashboard/tyk-dashboard-agent-user.json): Defines the user created in the standard Tyk Dashboard, used by the agent to synchronise API data.

## Usage

Once bootstrapped, the Governance Dashboard is accessible here:

- **URL**: http://tyk-governance-dashboard.localhost:8082
- **Username**: govn.user@example.com
- **Password**: m8YEVG4L

In the **API Repository** section, you'll see many APIs that have been synchronised from the Tyk Dashboard. The initial synchronisation is triggered automatically during bootstrap.

In the **Agents** section, you'll see an agent named *My Agent*, preconfigured with a *Tyk* provider. This provider synchronises OAS-based API definitions from the standard Tyk Dashboard.

### Synchronisation Example

To observe the synchronisation process manually:

1. Open the standard Tyk Dashboard: http://tyk-dashboard.localhost:3000
2. Create and save a new OAS-based API.
3. Open the Governance Dashboard: http://tyk-governance-dashboard.localhost:8082
4. Navigate to the **API Repository** section.
5. Click the **Re-sync** button.
6. The new API will now be available in the Governance Dashboard.
7. Use the Filter and search box to find it by name.
