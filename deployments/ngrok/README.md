# ngrok 

 This deployment runs ngrok docker image

 Using it you generates  an external ip you can use as a custom domain. Check "ngrok-custom-domain" api to see how to do that.


- [ngrok dashboard](http://localhost:4551)

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

 In case your tyk-demo runs for a more than 2 hours, you might need to restart the ngrok container to get a new ip:
 `./docker-compose-command.sh restart www-ngrok`
 Then, to get the new ip use
 `curl localhost:4551/api/tunnels --silent| jq ".tunnels[0].public_url" --raw-output`
