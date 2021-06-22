# ngrok 

 This deployment runs ngrok docker image

- [ngrok](http://localhost:4551)

## Setup

Run the `up.sh` script with the `ngrok` parameter:

```
./up.sh ngrok
```

## Usage

Get the ip from the output of the bootstrap script (`./up.sh`)

To get the ip at any time, run the following:
```
$ curl localhost:4551/api/tunnels --silent| jq ".tunnels[0].public_url" --raw-output
https://<dynamic-ngrok-allocated-ip>.ngrok.io
```
