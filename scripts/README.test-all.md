# Tyk Demo Deployment Test Script

This script automates the testing of all Tyk Demo deployments by creating, testing, and removing deployments. Deployments are processed consecutively in alphabetical order.

## Features
- Verifies Postman collections for each deployment.
- Skips deployments that do not meet predefined criteria.
- Logs detailed test results.

## Prerequisites
- Ensure all necessary tools are installed, including Docker.
- Run the script from the repository root.

## Usage
Run the script as follows:
```bash
./scripts/test-all.sh
```

## Testing Criteria
1. The deployment must have a correctly named Postman collection:
   - For the deployment directory `foo-bar`, the collection should be named `tyk_demo_foo_bar.postman_collection.json`. The name is prefixed with `tyk_demo_`, the deployment name is made snake case e.g. `foo_bar`, and finish with `.postman_collection.json`.
2. The Postman collection must:
   - Not contain the variable `test-runner-ignore` with the value `true`.
   - Include at least one test.
3. The deployment must be successfully created.

## Exit Codes
- `0`: All tests passed.
- Non-zero: Failures occurred. See logs for details.

## Logs
- Logs are written to the `logs/` directory.
- Use `less -r logs/test.log` for readable output.

## Notes
- The script removes all existing deployments at the start.
- Failures may occur due to environmental reasons; verify available resources and configurations.
- Expect the script to take a while to complete, as each deployment has to be created, tested and removed.
