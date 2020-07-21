# MQTT (IoT) Example - TCP proxy in Tyk

 This deployment runs Node-Red and Mosquitto to showcase a full MQTT use-case being reverse proxied through Tyk.

- Mosquitto - http://localhost:1883
- [Node-Red](http://localhost:1880)

## Setup

Run the `up.sh` script with the `mqtt` parameter:

```
./up.sh mqtt
```

## Usage

Everything is setup and wired automatically.

Log into the Node-Red dashboard to inspect the Dashboard at
```
http://localhost:1880
```

Note the nodes say `connected` underneath.  Tyk is actually intercepting the traffic from  the sensors and reverse proxying to the broker Mosquitto via TCP proxy.

Let's test the connection.  Follow these steps.

![rednode-debug-steps](./nodered-debug-steps.png)
