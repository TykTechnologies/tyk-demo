# ngrok 

This deployment runs an ngrok docker image.

Using it generates an external IP and hostname which makes the Tyk Gateway publicly accessible from the internet.

The ngrok deployment contains a dashboard which records all requests which pass through the ngrok tunnel.

- [ngrok dashboard](http://localhost:4040)

## Setup

Run the `up.sh` script with the `ngrok` parameter:

```
./up.sh ngrok
```

## Usage

The Ngrok tunnel URL is displayed in the output of the bootstrap script (`./up.sh`). 
The URL will be something that looks like this: `http://11e3-103-252-202-110.ngrok.io`

APIs can be accessed through the tunnel URL using the same paths as they are accessed through the Gateway URL. 
For example, using the example tunnel URL provided above, the Basic Open API can be accessed as follows:

- Gateway URL: http://tyk-gateway.localhost:8080/basic-open-api/get
- External Tunnel URL: http://11e3-103-252-202-110.ngrok.io/basic-open-api/get

Requests sent via the tunnel are recorded and displayed in the [Ngrok dashboard](http://localhost:4040). 
Try sending some requests through the tunnel URL to generate some data, then check the Dashboard to see what has been recorded.

You can also set the external url as custom domain in the api definition.
 
### Getting the tunnel URL

To get the tunnel URL at any time, run the following:
```
curl localhost:4040/api/tunnels --silent| jq ".tunnels[0].public_url" --raw-output
```

This will display the tunnel URL e.g. `https://<dynamic-ngrok-allocated-ip>.ngrok.io`.

The tunnel IP can also be seen in the [ngrok dashboard](http://localhost:4040).

### Renewing the Ngrok session

Anonymous ngrok sessions are capped at 2 hours. So after 2 hours you will need to restart the ngrok container to generate a new session and URL:
`./docker-compose-command.sh restart www-ngrok`

Then, to get the new URL use:

```
curl localhost:4040/api/tunnels --silent | jq ".tunnels[0].public_url" --raw-output
```