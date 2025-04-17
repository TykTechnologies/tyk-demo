# Troubleshooting Guide

This guide outlines common issues encountered while using the Tyk Demo and steps to resolve them.

## General Troubleshooting Steps

- Use Docker Desktop and macOS, as this is the intended deployment environment; Linux and Windows may require additional configuration.
- Run `./down.sh` to clean the environment before retrying `./up.sh`.
- Check logs in `logs/bootstrap.log` for detailed error messages.
- Refer to the relevant deployment’s `README.md` for additional setup instructions.

## Docker Issues

### Docker containers fail to start

Run:

```bash
docker ps -a
```

Look for containers that exited with errors. To inspect logs:

```
docker logs <container-name>
```

Also review `logs/bootstrap.log` for more information.

Common issues:
- Incorrect or missing environment variables
- Port conflicts
- Insufficient Docker resources (RAM/storage)

### Ports already in use

If ports such as 3000, 8080, or 5432 are already in use:

```bash
lsof -i :3000
```

Either stop the conflicting process or update the port numbers in the appropriate Docker Compose file.

### Error: `Version in "./docker-compose.yml" is unsupported`

This indicates Docker Compose v2+ is required.

Update Docker and Docker Compose to latest.

### Insufficient Resources

If containers fail unexpectedly, ensure Docker has been allocated sufficient CPU, RAM, and disk space.

Docker should have at least 4GB of RAM allocated.

## Bootstrapping Issues

### Error: `jq: command not found`

The `bootstrap.sh` script requires `jq`.

Install `jq`:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt-get install jq`

### Bootstrap stuck on `Request unsuccessful: wanted '200'...`

This message means the bootstrap script is polling for a service to become available. It usually resolves after 5–10 attempts.

If it continues indefinitely:
- Check the `logs/bootstrap.log` for the underlying issue
- Review logs of the service container that is not responding

## Environment File Issues

### Licence error displayed

Ensure the `.env` file exists at the root of the repo and includes:

```bash
DASHBOARD_LICENCE=<your valid licence>
```

> **Note:** The licence value should not include quotes or spaces.

To validate your licence:

```bash
./scripts/licences.sh
```

Check that the licence has not expired.

If it appears incorrect, follow the steps in the [getting started](../README.md) section to update it.

## Host Mapping Issues

### Browser requests do not resolve as expected

Hostnames may not be mapped to `127.0.0.1`.

To add the required hostnames, run:

```bash
sudo ./scripts/update-hosts.sh
```

## Feature Deployment Issues

### Feature deployment fails during bootstrap

Check `logs/bootstrap.log` for errors.

Also review the relevant feature deployment’s `README.md` to confirm prerequisites are met.

### MDCB feature doesn’t work

Ensure the following is set in your `.env` file:

```bash
MDCB_LICENCE=<your valid MDCB licence>
```

## Postman Request Issues

### Postman requests fail

Some requests are designed to fail — check the request description and test cases:
- Review `logs/bootstrap.log` for underlying issues.
- Run the test script and check for test failures:
  ```bash
  ./scripts/test.sh
  ```

## Resetting Issues

### `down.sh` doesn't remove expected containers

Check that `.bootstrap/bootstrapped_deployments` exists and is populated with th expected deployment names.

If not, manually remove remaining Docker resources:

```bash
docker ps -a
docker rm <container-id>
docker volume ls
docker volume rm <volume-name>
```
