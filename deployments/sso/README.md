# SSO Dashboard

Provides an SSO-enabled Tyk Dashboard in conjunction with the Tyk Identity Broker and Okta. It will connect to the same databases as the Standard Tyk deployment.

- [Tyk SSO-enabled Dashboard](http://localhost:3001)

## Setup

Run the `up.sh` script with the `sso` parameter:

```
./up.sh sso
```

## Usage

**Note:** This example is not very configurable right now, since it relies on a specific Okta setup which is only configurable by the owner of the Okta account (i.e. not you!). Would be good to change this at some point to use a self-contained method which can be managed by anyone. Please feel free to implement such a change an make a pull request. Anyway, here's the SSO we have...

The `dashboard-sso` container is set up to provide a Dashboard using SSO. It works in conjunction with the Identity Broker and Okta to enable this.

If you go to SSO-enabled Dashboard http://localhost:3001 (in a private browser session to avoid sending any pre-existing auth cookies) it will redirect you to the Okta login page, where you can use these credentials to log in:

  - Admin user:
    - Username: `dashboard.admin@example.org`
    - Password: `Abcd1234`
  - Read-only user:
    - Username: `dashboard.readonly@example.org`
    - Password: `Abcd1234`
  - Default user: (lowest permissions)
    - Username: `dashboard.default@example.org`
    - Password: `Abcd1234`

This will redirect back to the Dashboard, using a temporary session created via the Identity Broker and Dashboard SSO API.

Functionality is based on the `division` attribute of the Okta user profile and ID token. The value of which is matched against the `UserGroupMapping` property of the `tyk-dashboard` Identity Broker profile.