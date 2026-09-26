# pipgogo project context

- Use the name `pipgogo` consistently in code, documentation, and configuration.
- The user owns `pipgogo.com`.
- The Cognito custom sign-in domain is `https://auth.pipgogo.com`. Certificate, DNS, and Cognito domain are deployed through CloudFormation. HTTPS and Google authorization redirect preflight checks passed; a full interactive sign-in after migration still needs user testing.
- Use `https://auth.pipgogo.com` for new sign-in, token, and logout requests. The original hosted domain remains available for rollback:
  `https://pipgogo-e771ebb0-b949-11f1-8d17-06798145e65d.auth.us-west-2.amazoncognito.com`.
- The Cognito user pool is `us-west-2_qPlEDatlA`; the public app client ID is `5ungc4grbiid7de7rjbh0jn2ff`.
- A custom hosted domain does not change the JWT issuer: `https://cognito-idp.us-west-2.amazonaws.com/us-west-2_qPlEDatlA`.
- Native app callback/logout URLs remain `pipgogo://auth/callback` and `pipgogo://auth/logout`. A hosted-domain change does not automatically migrate these to Universal Links.

## Custom-domain implementation notes

- Manage AWS infrastructure through the backend CloudFormation templates so it remains reproducible.
- Cognito custom domains require an ACM certificate in `us-east-1`, even though this user pool is in `us-west-2`, plus DNS validation and a DNS record pointing to Cognito's CloudFront target.
- Verify the parent domain has the DNS A record Cognito requires. Do not replace existing website or mail DNS records to satisfy this requirement.
- Add the custom domain's `/oauth2/idpresponse` URL to the Google Web OAuth client's authorized redirects before switching sign-in traffic.
- Coordinate the Cognito hosted URL in the backend login-test configuration and iOS app configuration; verify Google sign-in, code exchange, refresh, logout, and backend token verification after migration.
- Never place Google client secrets or AWS credentials in source files or the iOS app. The Google secret lives in Secrets Manager at `pipgogo/dev/google-oauth`.
- DNS is managed by Route 53 in public zone `Z0395809B81JNLVOVUJ3`. The user approved a root A record `pipgogo.com -> 192.0.2.1` (TTL 300) because no root A record existed; it is only a Cognito prerequisite, not a website. The certificate stack `pipgogo-auth-certificate` in `us-east-1` manages this record and the ACM certificate. Coordinate any future root website DNS migration with this stack.

Reference: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-add-custom-domain.html

## iOS references

Backend project: `/Users/alikianzadeh/git/pipgogo-backend`. Read its `docs/api.md`, `docs/deployment.md`, and `docs/v1-scope.md` for the API contract and current scope. `pipgogo/App/AppConfiguration.swift` now uses the custom hosted sign-in URL `https://auth.pipgogo.com`. Rebuild/install the app to pick up this change.
