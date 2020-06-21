# Multi Data Centre Bridge

Uses Tyk Multi Data Centre Bridge (MDCB) to provide isolation and reliance to a Gateway. 

- [Tyk Worker Gateway](http://tyk-mdcb-gateway.localhost:8084)

The Worker Gateway, connected to MDCB, is bound to a single Organisation, so cannot access data from other Organisations. It also benefits from its own Redis instance, which it uses to cache data from the primary Redis in the `tyk` deployment.

MDCB architecture creates a Control Plane and a Data Plane:

- The Control Plane contains the base `tyk` deployment with the the core components, databases and MDCB
- The Data Plane contains the worker Gateways with their local Redis database

## Setup

MDCB requires its own licence. Provide your licence as a `MDCB_LICENCE` property in the `.env` file:

```
MDCB_LICENCE=<YOUR_MDCB_LICENCE>
```

Run the `up.sh` script with the `mdcb` parameter:

```
./up.sh mdcb
```

## Usage

One of the benefits of MDCB is that it provides Gateways in the Data Plane with reliancy against network partitions. If the Worker Gateway becomes disconnected from MDCB it will use the locally available Worker Redis to continue operating.

To simulate MDCB failure, this you stop the `tyk-mdcb` container by running this script:

```
./deployments/mdcb/scripts/stop-mdcb.sh
```

At this point the Worker Gateway will lose connection with MDCB. If you check the Gateway's logs you will see messages such as:

```
level=warning msg="[RPC STORE] RPC Reload Checker encountered unexpected error: gorpc.Client: [tyk-mdcb:9091]. Cannot decode response: [unexpected EOF]"
level=error msg="Can't purge cache, failed to ping RPC" error="gorpc.Client: [tyk-mdcb:9091]. Cannot obtain response during timeout=30s"
level=warning msg="Keyspace warning: gorpc.Client: [tyk-mdcb:9091]. Cannot obtain response during timeout=30s"
level=info msg="Can't connect to RPC layer" error="gorpc.Client: [tyk-mdcb:9091]. Cannot obtain response during timeout=30s" prefix="RPC Conn Mgr"
```

You can then try accessing APIs via the Worker Gateway:

```
curl http://tyk-worker-gateway.localhost:8084/basic-open-api/get
```

You will receive a response, despite the Gateway being disconnected from MDCB. In a typical multi-data centre deployment, this would allow the Gateway to continue operating in the event of connectivity disuption between it and the primary data centre where MDCB is deployed.