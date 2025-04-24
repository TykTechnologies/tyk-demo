# Tyk Demo Testing Scripts

## Overview

This repository contains scripts for testing Tyk deployments. The tools support running both individual and batch deployment tests using Postman collections and custom test scripts.

## Scripts

The repository includes two main testing scripts:

1. **`test.sh`** - Tests currently bootstrapped deployments
2. **`test-all.sh`** - Tests all deployments sequentially

Both scripts leverage common testing utilities from `test-common.sh` and provide detailed logging and result summaries.

## Prerequisites

- Docker and Docker Compose installed

## Directory Structure

```
Tyk Demo/
├── .bootstrap/
│   └── bootstrapped_deployments                # List of active bootstrapped deployments
├── deployments/
│   └── [deployment_name]/                      # Contains deployment-specific files and tests
├── logs/
│   ├── test.log                                # General test execution logs
│   ├── postman.log                             # General Postman test logs
│   ├── bootstrap.log                           # General deployment bootstrap logs
│   ├── postman-{deployment}-{timestamp}.log    # Preserved Postman test logs
│   ├── bootstrap-{deployment}-{timestamp}.log  # Preserved deployment bootstrap logs
│   └── test-{deployment}-{timestamp}.log       # Preserved deployment test logs
└── scripts/
    ├── test-common.sh                          # Common testing functions
    ├── test.sh                                 # Tests currently bootstrapped deployments
    └── test-all.sh                             # Tests all available deployments
```

## Usage

### Testing Bootstrapped Deployments

Use this script to test deployments that are already bootstrapped:

```bash
./scripts/test.sh
```

This script:
- Checks for bootstrapped deployments in `.bootstrap/bootstrapped_deployments`
- Runs Postman tests and custom scripts for each deployment
- Logs results and displays a summary table
- Exits with status code 1 if any fail, otherwise 0

### Testing All Deployments

Use this script to test all deployments in the `deployments` directory:

```bash
./scripts/test-all.sh
```

This script:
- Finds all deployment directories
- For each deployment:
  - Creates the deployment using `up.sh`
  - Runs Postman tests if available
  - Runs custom scripts if available
  - Preserves logs with deployment name and timestamp
  - Tears down the deployment using `down.sh`
- Generates a comprehensive summary table with test results
- Displays statistics about passed, failed, and skipped deployments
- Exits with status code 1 if any fail, otherwise 0

## Pre-Test Checks

For a deployment to be tested, the follow criteria must be met.

1. The deployment must have a correctly named Postman collection:
   - Use the deployment name in the file name
     - For example, if the deployment directory is `foo-bar`, the collection must be named `tyk_demo_foo_bar.postman_collection.json`
   - Prefix the name with `tyk_demo_`
   - Convert the deployment name to snake case
     - For example, `foo-bar` becomes `foo_bar`
   - The file name finishes with `.postman_collection.json`
2. The Postman collection must:
   - Not contain the variable `test-runner-ignore` with the value `true`.
   - Include at least one test.

Deployments that do not meet the criteria will be skipped.

Additionally, the `test-all.sh` script will not test deployment that fail during bootstrap.

## Test Results

Both scripts generate a summary table that includes:

| Column | Description |
|--------|-------------|
| Deployment | Name of the deployment |
| Result | Overall test result (Passed/Failed/Skipped) |
| Bootstrap | Deployment creation result (Passed/Failed/N/A) |
| Postman | Postman test results (Passed/Failed/N/A) |
| Test Scripts | Custom script test results (X/Y: Passed/Failed or N/A) |

## Logs

The scripts generate several log files:
- `test.log`: General test execution logs, created by the test scripts
- `postman.log`: Detailed Postman test results, created by the Postman test runner
- `bootstrap.log`: Deployment creation logs, created by the `bootstrap.sh` script

Additionally, the `test-all.sh` script preserves these logs for each deployment, by renaming them with the deployment name and timestamp.

## Exit Codes

- 0: All tests passed or were skipped
- 1: One or more tests failed

## Adding Tests

### Postman Tests

Place Postman collection files in the deployment directory. The collection should be named according to the pattern defined in `test-common.sh`.

### Custom Test Scripts

Add custom test scripts to the deployment directory. Scripts should follow naming conventions defined in `test-common.sh` and return 0 for success and non-zero for failure.

## Troubleshooting

- For failed deployments, container logs are automatically captured
- Check preserved log files with the deployment name and timestamp for detailed error information
- Verify Docker is running and has sufficient resources
- Ensure needed ports are available for the deployments