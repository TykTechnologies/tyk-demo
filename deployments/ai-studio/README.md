# Tyk AI Studio

To run Tyk AI Studio:

1. Add your license to `.env`:

`AI_STUDIO_LICENSE=<YOUR_AI_STUDIO_LICENSE>`

2. Ensure the demo hostnames are present in `/etc/hosts`:

```shell
sudo ./scripts/update-hosts.sh
```

3. Run the Tyk Demo `up.sh` script with the `ai-studio` argument:

```shell
./up.sh ai-studio
```

4. Visit AI Studio in your browser at https://ai-studio.localhost:4000

The deployment uses a self-signed certificate, so your browser will prompt you to accept it the first time.

5. Log on using:

```
dev@tyk.io
T0pSecR3t!
```
