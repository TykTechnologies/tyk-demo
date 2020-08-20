# MQTT (IoT) Example - TCP proxy in Tyk

 This deployment runs Node-Red and Mosquitto to showcase a full MQTT use-case being reverse proxied through Tyk.

- [Node-Red](http://localhost:1880)
- [Mosquitto](http://localhost:1883)


## Setup

Run the `up.sh` script with the `mqtt` parameter:

```
./up.sh mqtt
```

## Usage

Everything is setup and wired automatically.

Log into the Node-Red dashboard to test the flow at
```
http://localhost:1880
```

Note the nodes say `connected` underneath.  Tyk is actually intercepting the traffic from the sensors and reverse proxying to the Mosquitto broker via TCP proxy.

Let's test the connection.  Follow these steps.

![rednode-debug-steps](./nodered-debug-steps.png)
