# PipPipGo — traveler-intelligence rebuild

## Authoritative scope

The user requested a major rebuild on September 27, 2026. Use the
[new requirements](docs/traveler-intelligence-requirements.md), [roadmap](ROADMAP.md),
and [implementation notes](docs/traveler-intelligence.md). The prior questionnaire,
check-in and companion-package feature sequence is superseded. Its instructions and
historical evidence are retained in `docs/archive/2026-09-27-legacy-AGENTS.md`.

Preserve Google/Cognito authentication and working ECS/DynamoDB architecture. Rebuild the
product around trip intake, getting to know the traveler, persistent memory, lightweight plans,
current-trip learning and user-controlled adaptation. **Pip never overplans.** Fixed commitments
outrank suggestions; trip-specific context outranks general memory. Imported facts require review.
Never infer sensitive needs or turn temporary feedback into permanent preferences. Corrections win.

The latest user-selected model is OpenAI GPT-6 Astra through the direct OpenAI Responses API. Use a server-side
OpenAI API key from Secrets Manager or the local environment; no provider credentials belong in the iOS bundle. Do not substitute
a model without user instruction. Record model agreement/access, IAM deployment, live inference,
mocked tests and physical-device acceptance separately.

## Project time tracking

Maintain one identical `TIME_LOG.md` in both repositories. Capture session start/end and known
pauses, contributor and milestone. Count cross-repository work only once. Codex elapsed session
time is not human labor. Keep estimates and unknown historical time separate. Never invent exact
durations or create a scheduled time-tracking automation. Mirror roadmap milestone updates.

## Engineering rules

Read the other repository's AGENTS.md before modifying it. Preserve server-derived ownership,
immutable retry body/key/version, explicit conflict review, account-switch reset/late-response
fences, account-deletion disable markers and retained AWS data. New journey/memory/traveler records
are separate from legacy product records. Legacy data is retained, not automatically migrated.
Manage AWS infrastructure with the backend CloudFormation templates. Coordinate app/API rollout;
the rebuilt app requires new journey endpoints and is not compatible with the old product API.

Backend checks: `uv run pytest -q`, `uv run ruff check app scripts tests`, and
`uv run ruff format --check app scripts tests`. iOS uses Local/Dev/Prod schemes; run relevant
simulator tests and signed builds. Mocked tests/builds do not prove live provider or device acceptance.
Use the first four-day San Diego scenario in requirement section 28 as core end-to-end acceptance.
Later location, pilot, hands-free and custom hardware milestones remain sequential product work.

## Retained authentication and infrastructure references

- Display the app name as `PipPipGo` in all user-facing UI, app display names, and documentation. Use lowercase `pippipgo` for repository names, checkout paths, public domains and new documentation examples. When documenting existing technical identifiers, Xcode project/scheme names, bundle IDs, URL schemes, environment variables or infrastructure resources, use their exact configured spelling; do not imply a runtime rename through documentation edits. The requested public domain is now `pippipgo.com`; domain migration is deployed at `auth.pippipgo.com`.
- The user owns `pipgogo.com` and `pippipgo.com`; the latter is registered at GoDaddy and delegated to AWS Route 53 zone `Z04005221I5Q1A2V5ZO9R`. Active sign-in domain: `https://auth.pippipgo.com`. The certificate, Google redirect, and new custom domain are deployed. The old custom sign-in domain was removed; the AWS prefix domain remains available. See backend `infra/pippipgo-migration.md`.
- The Cognito custom sign-in domain is `https://auth.pippipgo.com`, deployed through CloudFormation. Historical Step 1 verification on the old domain passed: iPhone sign-in, session restoration, refresh after expiry and logout; live Chrome two-account trip isolation and refresh-token revocation. Evidence and test boundaries are recorded in backend `docs/auth-verification.md`.
- Use `https://auth.pippipgo.com` for new sign-in, token, and logout requests. The original hosted domain remains available for rollback:
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
- Active DNS: `pippipgo.com` is registered at GoDaddy and delegated to Route 53 zone `Z04005221I5Q1A2V5ZO9R`. Certificate stack `pippipgo-auth-certificate` in `us-east-1` manages the certificate and root placeholder A record (`192.0.2.1`, TTL 300); it is a Cognito prerequisite, not a website. Coordinate future website DNS changes with this stack. The old `pipgogo-auth-certificate` stack and `pipgogo.com` zone remain retained for recovery.

Reference: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-add-custom-domain.html

## iOS references

Backend project: `/Users/alikianzadeh/git/pippipgo-backend`. Read its `docs/api.md`, `docs/deployment.md`, and `docs/v1-scope.md` for the API contract and current scope. `pipgogo/App/AppConfiguration.swift` now uses the custom hosted sign-in URL `https://auth.pippipgo.com`. Rebuild/install the app to pick up this change.
