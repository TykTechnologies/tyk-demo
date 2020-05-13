# TLS Gateway

This is a TLS-enabled Gateway. It uses a self-signed certificate, so make sure to instruct your HTTP client is ignore certificate verification failure.

- [Tyk TLS Gateway](https://localhost:8081/basic-open-api/get)

## Setup

Run the `up.sh` script with the `tls` parameter:

```
./up.sh tls
```

## Usage

Send any request to the TLS-enabled gateway:

```
curl https://localhost:8081/basic-open-api/get
```