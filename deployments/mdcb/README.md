# Multi Data Centre Bridge

This deployment uses Tyk Multi Data Centre Bridge (MDCB) to provide isolation and resiliance to a worker Gateway.

- The worker Gateway, connected to MDCB, is bound to a single Organisation, so cannot access data from other Organisations. 
- It also benefits from its own Redis instance, which it uses to cache data from the primary Redis in the `tyk` deployment. This enables it to continue functioning even if it becomes disconnected from MDCB.

MDCB architecture creates a Control Plane and a Data Plane:

- The Control Plane contains the base `tyk` deployment with the the core components, databases and MDCB
- The Data Plane contains only the worker Gateways with their local Redis database
- MDCB is the link between the Planes

The worker Gateway can be accessed here:
- [Tyk Worker Gateway](http://tyk-worker-gateway.localhost:8084)

## Setup

### Licence

MDCB requires its own licence. Provide your licence as a `MDCB_LICENCE` property in the `.env` file:

```
MDCB_LICENCE=<YOUR_MDCB_LICENCE>
```

The bootstrap process will fail if the licence is not present.

### Access to MDCB Docker image

The MDCB image used by this deployment, `tykio/tyk-mdcb-docker`, is hosted in a private repository. Request access to this repository via your Tyk account manager.

The bootstrap process will fail if you do not have access to this repository.

### Bootstrap

To use this deployment, run the `up.sh` script with the `mdcb` parameter:

```
./up.sh mdcb
```

### Postman Collection

You can import the deployment-specific Postman collection `tyk_demo_mdcb.postman_collection.json`.

## Usage

One of the benefits of MDCB is that it provides Gateways in the Data Plane with reliancy against network partitions. If the Worker Gateway becomes disconnected from MDCB it will use the locally available Worker Redis to continue operating.

### 1. Simulate connectivity issue

To simulate MDCB failure, stop the `tyk-mdcb` container by running this script:

```
./deployments/mdcb/scripts/stop-mdcb.sh
```

### 2. Observe the Worker Gateway logs
At this point the Worker Gateway will lose connection with MDCB. Check the Gateway's logs for messages:

```
docker logs tyk-demo_tyk-worker-gateway_1
```

You will see entries such as:

```
level=warning msg="[RPC STORE] RPC Reload Checker encountered unexpected error: gorpc.Client: [tyk-mdcb:9091]. Cannot decode response: [unexpected EOF]"
level=error msg="Can't purge cache, failed to ping RPC" error="gorpc.Client: [tyk-mdcb:9091]. Cannot obtain response during timeout=30s"
level=warning msg="Keyspace warning: gorpc.Client: [tyk-mdcb:9091]. Cannot obtain response during timeout=30s"
level=info msg="Can't connect to RPC layer" error="gorpc.Client: [tyk-mdcb:9091]. Cannot obtain response during timeout=30s" prefix="RPC Conn Mgr"
```

These indicate that the Gateway has lost its connection to MDCB.

### 3. Access the API via the Worker Gateway

You can then try accessing APIs via the Worker Gateway:

```
curl http://tyk-worker-gateway.localhost:8084/basic-open-api/get
```

You will receive a response, despite the Gateway being disconnected from MDCB. In a typical multi-data centre deployment, this would allow the Gateway to continue operating in the event of connectivity disuption between it and the primary data centre where MDCB is deployed.

While the Gateway is disconnected, it only has access to information stored in the Date Plane's local Redis, so any modifications to data or events generated in the Control Plane will not be accessible or recognised. But once the connection to MDCB is restored, the Gateway's access to the data and events within Control Plane is also restored.

### 4. Restore MDCB

To restore MDCB, start the `tyk-mdcb` container by running this script:

```
./deployments/mdcb/scripts/start-mdcb.sh
```

The Worker Gateway is now able to access the data and events in the Control Plane.
