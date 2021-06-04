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
$ curl localhost:4551/api/tunnels | jq ".tunnels[0].public_url" --raw-output
https://<ngrok-allocated-ip>.ngrok.io
```

Now try a dirty payload:
```
$ curl 'localhost:8500/?param="><script>alert(1);</script>'

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>403 Forbidden</title>
</head><body>
<h1>Forbidden</h1>
<p>You don't have permission to access /
on this server.<br />
</p>
</body></html>
```

Our WAF catches the response and returns a `403`.   

Now we try through Tyk.

First, with a clean request, we should get response from upstream's IP endpoint
```
$ curl localhost:8080/waf/ip
{
  "origin": "172.30.0.1, 147.253.129.30"
}
```

Now with a dirty requests, the WAF will detect malicious payload and instruct Tyk to deny
```
$ curl 'localhost:8080/waf/ip?param="><script>alert(1);</script>'
{
    "error": "Bad request!"
}
```
