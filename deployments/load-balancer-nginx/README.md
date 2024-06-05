# Load Balancer

This deployment is an example of a load balanced deployment, using a load balancer and gateway cluster. 

The load balancer (Nginx) uses round robin load balancing to spread requests across three gateways. Tyk could load balance itself, but this isn't a typical real-life approach, so Nginx was chosen instead.

## Setup

Run the `up.sh` script with the `load-balancer-nginx` parameter:

```
./up.sh load-balancer
```

### Configuration

The two gateways deployed by this deployment (`tyk-gateway-3` and `tyk-gateway-4`) use the same configuration at `tyk-gateway` from the `tyk` deployment. This allows them to operate together as a load balanced cluster.

The load balancer is configured with different upstream groups. These have been set up to target different gateways:

| Group Name         | URL         | Gateways in Group           | Note |
| :----------- | :-------------- | :------------------------- | :---
| LB3 | http://localhost:8091/lb3 | `tyk-gateway`, `tyk-gateways-3` and `tyk-gateway-4` | This is the correct setup for this deployment.
| LB2 | http://localhost:8091/lb2 | `tyk-gateway` and `tyk-gateways-3` | This is misbalanced, as it targets only two of the three gateways.
| LB1 | http://localhost:8091/lb1 | `tyk-gateway` | This is misbalanced, as it targets only one of the three gateways.

The purpose of the misbalanced gateways is to show the effect it has on distributed rate limiting. Misbalanced gateways that use distributed rate limiting will result in rate limits being enforced at an lower rate i.e. 10rps instead of 20rps. This is because the gateways assume that load is spread evenly across the cluster, so calculate their distributed limit accordingly e.g. for 30rps, 3 gateways will each enforce 10rps. If only two of those gateways receive load then only 20rps is possible.

Note that the gateway `tyk-gateway-2` from the `tyk` deployment is not included in any of the upstream groups. This is because it uses segmentation tags, which reduce the APIs that it handles, making it unsuitable for clustering with the other gateways.

## Usage

Send requests to the load balancer, using one of the three load balanced paths e.g. http://localhost:8091/lb3/basic-open-api/get. The `lb3` path is load balanced across all three gateways.

The listen path is stripped from the requests by the load balancer, so only the following path elements will reach the gateway e.g. the previous example becomes http://tyk-gateway:8080/basic-open-api/get.

