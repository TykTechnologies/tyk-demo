# Tyk Demo Health Check - Blackbox Exporter

This deployment demonstrates how Tyk’s health check endpoints can be used to monitor the status of Tyk components.

The setup uses Prometheus with Blackbox Exporter to monitor the health check endpoints, and Grafana to display the results in a dashboard. 

The following components are monitored:
- Tyk Dashboard
- Tyk Gateways (Control Plane and Data Plane)
- MDCB (Multi-Data Centre Bridge)
- Upstream APIs

A pre-configured [Tyk System Health dashboard](http://localhost:3200/d/tyk-system-health) is available in [Grafana](http://localhost:3200), providing an overview of the health and status of the Tyk components.

For optimal results, it is recommended to deploy the `mdcb` service alongside this setup. However, this is optional. If MDCB is not deployed, the monitoring will report MDCB-related components as unavailable, verifying that the monitoring system is functioning correctly.

---

## Setup

To deploy the recommended configuration with MDCB:

```bash
./up.sh mdcb healthcheck-blackbox
```

Ensure you provide a valid MDCB licence by setting the `MDCB_LICENCE` variable in the `.env` file.

To deploy without MDCB, use the following command:

```bash
./up.sh healthcheck-blackbox
```

---

## Usage

After deployment, you can access [Grafana](http://localhost:3200) using the default credentials:
- **Username**: `admin`
- **Password**: `abc123`

Navigate to the [Tyk System Health dashboard](http://localhost:3200/d/tyk-system-health) in the [Dashboards section](http://localhost:3200/dashboards) to monitor the status of your Tyk components.

### Simulating Failure and Recovery

This section explains how to simulate a component failure and observe its recovery in the Tyk System Health dashboard.

#### Simulating Failure

1. Stop one of the monitored Tyk components by running the following command:

    ```sh
    docker stop tyk-demo-tyk-gateway-1
    ```

    Stopping this container will cause two probes to report a failure:
    - **Gateway Component Probe**
    - **Upstream API Probe**

2. Open the Tyk System Health dashboard. Two instances will now be displayed as down.  
   **Note:** Probes run at 15-second intervals, so there may be a short delay before the changes appear in the dashboard.

#### Simulating Recovery

1. Start the stopped container using the command below:

    ```sh
    docker start tyk-demo-tyk-gateway-1
    ```

2. Refresh the dashboard to confirm that the previously down components are now marked as up and operational.

