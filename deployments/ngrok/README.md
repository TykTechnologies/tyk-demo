# Ngrok 

 This deployment runs Ngrok docker image

 Using it generates an external IP you can use as a custom domain. Check "ngrok-custom-domain" api to see how to do that.

- [Ngrok dashboard](http://localhost:4040)

## Setup

Run the `up.sh` script with the `ngrok` parameter:

```
./up.sh ngrok
```

## Usage

Get the tunnel URL from the output of the bootstrap script (`./up.sh`). The URL will be something like http://11e3-103-252-202-110.ngrok.io.

APIs can be access through the tunnel hostname with the same paths as accessing them through the Gateway. For example, using the example tunnel provided above, the Basic Open API can be accessed as follows:

- Gateway URL: http://tyk-gateway.localhost:8080/basic-open-api/get
- Tunnel URL: http://11e3-103-252-202-110.ngrok.io/basic-open-api/get

Requests sent via the tunnel will be recorded on the [Ngrok dashboard](http://localhost:4040). Try sending some requests through the tunnel URL then check the Dashboard to see the recorded data.

### Getting the tunnel URL

To get the tunnel URL at any time, run the following:
```
curl localhost:4040/api/tunnels --silent| jq ".tunnels[0].public_url" --raw-output
```

This will display the tunnel URL e.g. `https://<dynamic-ngrok-allocated-ip>.ngrok.io`.

The tunnel IP can also be seen in the [Ngrok Dashboard](http://localhost:4040).

### Renewing the Ngrok session

Anonymous Ngrok sessions are capped at 2 hours. So after 2 hours you will need to restart the Ngrok container to get a new IP:
`./docker-compose-command.sh restart www-ngrok`

Then, to get the new IP use
`curl localhost:4040/api/tunnels --silent | jq ".tunnels[0].public_url" --raw-output`
