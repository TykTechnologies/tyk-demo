# ngrok 

 This deployment runs ngrok docker image

 Using it generates an external IP you can use as a custom domain. Check "ngrok-custom-domain" api to see how to do that.

- [Ngrok dashboard](http://localhost:4040)

## Setup

Run the `up.sh` script with the `ngrok` parameter:

```
./up.sh ngrok
```

## Usage

Get the IP from the output of the bootstrap script (`./up.sh`)

To get the IP at any time, run the following:
```
$ curl localhost:4040/api/tunnels --silent| jq ".tunnels[0].public_url" --raw-output
https://<dynamic-ngrok-allocated-ip>.ngrok.io
```

Anonymous Ngrok sessions are capped at 2 hours. So after 2 hours you will need to restart the Ngrok container to get a new IP:
`./docker-compose-command.sh restart www-ngrok`

Then, to get the new IP use
`curl localhost:4040/api/tunnels --silent | jq ".tunnels[0].public_url" --raw-output`
