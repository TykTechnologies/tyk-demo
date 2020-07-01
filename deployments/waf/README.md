# WAF (Web Application Firewall) - ModSecurity Plugin

 This deployment runs ModSecurity, an OSS WAF, with the popular Core Ruleset.

- [WAF](http://localhost:8500)

## Setup

Run the `up.sh` script with the `waf` parameter:

```
./up.sh waf
```

## Usage

Open a terminal and curl the WAF
```
$ curl localhost:8500
hello world
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