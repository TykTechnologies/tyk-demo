## Notes on setting up Dashboard SSO

Once `bootstrap.sh` is complete:

1. Create an Application on Okta
  - Set the values based on the TIB URLs
2. Update `volumes/tyk-identity-broker/profiles.json`:
  - Set `IdentityHandlerConfig.DashboardCredential` to the Dashboard User API Credentials
  - Set `DefaultUserGroupID` to the object id of User Group 'Default'
  - Set `UserGroupMapping.read-only` to the object id of User Group 'Read-only'
  - Set `UserGroupMapping.admin` to the object id of User Group 'Admin'
3. Restart TIB container

To use SSO:

1. Go to http://localhost:3010/auth/tyk-dashboard/openid-connect in a private browser session, this will redirect to Okta login
2. Submit login form using credentials
  - Admin user:
    - Username: `dashboard.admin@example.org`
    - Password: `Abcd1234`
  - Read-only user:
    - Username: `dashboard.readonly@example.org`
    - Password: `Abcd1234`
  - Default user:
    - Username: `dashboard.default@example.org`
    - Password: `Abcd1234`

3. This will redirect to an SSO session in the Dashboard