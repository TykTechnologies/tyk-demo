# Troubleshooting Guide

This guide outlines common issues encountered while using the Tyk Demo and steps to resolve them. If your issue isn't listed, please consider opening a pull request once resolved to help others.

## General Troubleshooting Steps

- Ensure you are using Docker Desktop on macOS, as this setup was created and tested on macOS. Linux and Windows may require additional configuration.
- Run `./down.sh` to clean the environment before retrying `./up.sh`.
- Check logs in `logs/bootstrap.log` for detailed errors.
- Check the relevant deployment’s `README.md`.

## Docker Issues

### Docker containers fail to start

Run:

```bash
docker ps -a
```

Look for containers that exited with errors. Check logs:

```
docker logs <container-name>
```

Also check `logs/bootstrap.log` for indications of cause.

Common issues:
- Incorrect or missing environment variables
- Port conflicts
- Insufficient resources (RAM/storage)

### Ports already in use

If ports like 3000, 8080, or 5432 are already used by another process:

```bash
lsof -i :3000
```

Either stop the conflicting service or update the port numbers in the relevant Docker Compose file.

### Error: `Version in "./docker-compose.yml" is unsupported`

Docker Compose v2+ is required.

Update Docker and Docker Compose to latest.

### Insufficient Resources

If containers unexpectedly error, check that Docker has been allocated sufficient CPU, RAM and storage resources.

The most important resource is RAM, for which Docker should be allocated at least 4GB.

## Bootstrapping Issues

### Error: `jq: command not found`

The `bootstrap.sh` script requires `jq`.

Install `jq`:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt-get install jq`

### Bootstrap gets stuck with `Request unsuccessful: wanted '200'...` message

This message occurs when the bootstrap process is waiting on a service to become available. It should usually disappear after 5-10 attempts.

If the error loops indefinitely:
- Check the `logs/bootstrap.log` for indications of cause
- Check container logs of the service returning the unsuccessful result

## Environment File Issues

### Licence error displayed

Ensure your `.env` file exists at the root of the repo and contains:

```bash
DASHBOARD_LICENCE=<your valid licence>
```

> **Note:** Licence should not include quotes or extra spaces around the key.

Additionally, run the `licences.sh` script to check your licences:

```bash
./scripts/licences.sh
```

Check that the licence has not expired.

If the licence doesn't look correct, update it as per the process defined in the [setup guide](SETUP.md).

## Host Mapping Issues

### Browser requests do not resolve as expected

Hostnames not mapped to 127.0.0.1.

Run the script to add the hostnames:

```bash
sudo ./scripts/update-hosts.sh
```

## Feature Deployment Issues

### Feature deployment fails during bootstrap

Review `logs/bootstrap.log` for indications of error.

Review the deployment `README.md` to ensure any prerequisites are handled.

### MDCB feature doesn’t work

Ensure `MDCB_LICENCE` is set in your `.env` file.

## Postman Issues

### Postman requests fail

Some requests are designed to fail. Check the request description and tests.

Review the `logs/bootstrap.log` file for indications of error.

Run `scripts/test.sh` to validate the current deployment.

## Resetting Issues

### `down.sh` doesn't remove expected containers

Ensure the `.bootstrap/bootstrapped_deployments` file exists and is correctly populated. 

If not, manually remove remaining resources (containers, volumes) using `docker` commands.
