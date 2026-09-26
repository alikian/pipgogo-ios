# pipgogo project context

- Use the name `pipgogo` consistently in code, documentation, and configuration.
- The user owns `pipgogo.com`.
- The Cognito custom sign-in domain is `https://auth.pipgogo.com`, deployed through CloudFormation. Step 1 authentication verification passed: iPhone sign-in, session restoration, refresh after expiry and logout; live Chrome two-account trip isolation and refresh-token revocation. Evidence and test boundaries are recorded in backend `docs/auth-verification.md`.
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


## Authentication verification checkpoint — September 25, 2026

- A signed Debug build was installed and launched on the connected iPhone 12 using `https://auth.pipgogo.com` and the LAN backend at `http://192.168.0.156:8765`. Verify the Mac address and server availability on later runs.
- Fixed duplicate OAuth callback parameters crashing the parser and literal `+` handling in OAuth form bodies. The networking test suite is serialized because its mock URLProtocol uses shared response state.
- All 15 simulator tests passed, including callback/state/PKCE, code exchange, refresh, revocation request and account response checks. These mocked tests do not prove live Google sign-in or revocation.
- **Step 1 complete (September 25, 2026):** signed iPhone build and session restoration were agent-verified; sign-in, logout persistence and the 16-minute expiry/refresh test were user-confirmed. Agent-operated Chrome verified live refresh-token revocation (`invalid_grant` after a working baseline), B denied read/list/overwrite of A's trip, A's original trip unchanged, and test-trip soft deletion. Final browser test session signed out. See backend `docs/auth-verification.md` for evidence and limits. Step 2.1 is now complete; next is Step 2.2, the traveler profile.

## Step 2 milestones — basic iOS trip flow

Implement these milestones sequentially and report each independently. Milestone 2.1 is complete. Milestone 2.2 is implemented with tests and a signed device installation; physical-device save/reopen/clear confirmation is pending. Milestones 2.3–2.8 have not started. Keep Step 1 authentication working throughout. The API contract is in the backend `docs/api.md`.

| Milestone | Scope | Completion check |
| --- | --- | --- |
| 2.1 — Completed: shared API client | Extend authenticated requests beyond account loading; decode records and structured errors; support expected versions, stable client UUIDs and idempotency keys. Retry the same operation with the same body/key/version, including after token refresh. Expose 409 details without automatically overwriting data. | Focused tests prove header/encoding behavior, retry identity, bounded authentication retry, and conflict/error decoding; existing auth tests still pass. |
| 2.2 — Implemented; device acceptance pending | Add profile navigation, initial empty state, load/edit/save optional preferences, and clearing optional values. Preserve the draft on errors; show a conflict and let the user review server data before choosing how to resolve it. | Save, reopen and edit on device; clearing values works; failed saves and conflicts retain the draft. |
| 2.3 — Companions | List, create, edit and delete recurring companions using stable UUIDs. Explain deletion rejection when a companion belongs to an active trip. Reuse the profile milestone's save/conflict behavior. | Create/edit/delete a companion; verify an in-use companion cannot be deleted and local edits survive failed saves. |
| 2.4 — Trip list and creation | Add empty/list/detail navigation and a new-trip form for destination, optional dates, accommodation and selected companions. Preserve supported fields when serializing replacement writes. | Create a trip, navigate away and reload it with its selected companions; a retried creation cannot create a duplicate trip. |
| 2.5 — Trip editing and deletion | Edit existing trip context and optional fields; validate dates and other API constraints. Present version conflicts without losing the draft; require deliberate resolution before retrying against a newer version. Explain soft deletion and confirm before deleting. | Edit and reload; simulate a concurrent edit and resolve it; delete removes the trip from the active list without claiming permanent history erasure. |
| 2.6 — Pre-trip check-in | Show current trip context, capture requests/concerns, and confirm the current trip version. Clearly report unavailable live travel data and require reconfirmation after a trip change. | Save/reopen a check-in; an intervening trip edit cannot silently confirm stale context. |
| 2.7 — Partial companion package | Generate, list and display package editions; authenticate JSON download and show saved trip information, creation time and missing guidance. Explain privacy implications and make optional profile/companion/reservation inclusion explicit. | Generate after a valid check-in; retry yields the same edition; download/display works and partial/unavailable content is clearly labeled. Durable offline storage remains Step 4. |
| 2.8 — Integrated acceptance | Exercise profile → companions → trip → edit → check-in → package on the physical iPhone. Check account switching, error recovery and existing sign-in/refresh/logout. Record device results separately from mocked tests. | Complete the journey with the real development backend; record results and limitations, then mark Step 2 complete. |

### Milestone 2.1 result — September 25, 2026

- Shared iOS API client now supports known backend routes, generic records/lists/sync, immutable encoded mutation requests, caller-owned UUIDs, idempotency keys, expected versions, and authenticated package bytes.
- A 401 triggers at most one token refresh and resend of the identical request. Transport/server/conflict failures are returned for caller-controlled handling. Structured 409 details/current record and 422 field details are preserved; no automatic overwrite or version change occurs.
- Existing account loading uses the shared authentication retry. No new product screens were added.
- Verification: **29 iOS tests passed**, including all 15 existing auth/account tests and 14 shared-client cases; signed Debug iPhone build passed. HTTP mutation tests are mocked; live feature acceptance remains with the later screen milestones.
- Integration contract: iOS `docs/api-client.md`. Future feature stores must retain draft/request identity on uncertain outcomes and cancel/discard account-scoped work on sign-out. Durable offline persistence remains Step 4.

### Milestone 2.2 implementation — September 25, 2026

- Account navigation now opens the optional traveler profile: nickname, home base, age range, usual party and all current preference fields. Empty/cleared values follow replacement PUT semantics.
- Session-owned ProfileStore preserves drafts across navigation, freezes uncertain writes for exact retry, and requires explicit local/server conflict review. Keeping a draft requires a separate Save against the reviewed version with a new key; choosing the server copy requires confirmation.
- Initial load failures prevent overwriting an unseen profile. Sign-out cancels/resets profile work; stale responses cannot repopulate the store. Unsaved drafts remain in memory only, with this limitation shown in the UI.
- Verification: **42 iOS tests passed** (29 previous plus 13 profile/service cases). Signed Debug build was installed and launched on the connected iPhone 12. User confirmation of save/reopen/edit/clear on the device is pending; do not mark milestone 2.2 fully accepted yet.
- Implementation/acceptance guide: iOS `docs/traveler-profile.md`. Milestone 2.3 (companions) has not started.

Full offline outbox/sync, durable offline package storage and automatic conflict merging remain Step 4. Live AI and verified travel guidance remain Step 3. Milestones 2.1–2.7 must still handle errors and conflicts correctly in their online flows; do not defer basic retry safety or preserving an open draft.

## Account selection — current configuration

The private-browser workaround was superseded by an in-place CloudFormation upgrade to Essentials and Managed Login v2. `EnableManagedLogin=true` selects this configuration and creates default mobile-client branding. Both custom/prefix domains forward `prompt=select_account` to Google. iOS explicitly requests that prompt and uses `prefersEphemeral: false`, allowing the browser account chooser. Accounts present only in the Gmail app may not appear in this browser session.

CloudFormation reached UPDATE_COMPLETE without resource replacements; pool/client IDs and the issuer are unchanged. Chrome chooser, Google sign-in/code exchange/backend access and browser refresh/revocation/logout were checked after upgrade. All 42 iOS tests passed; the signed build was installed on the connected iPhone. Physical-iPhone chooser confirmation and profile milestone 2.2 device acceptance remain pending.

See backend `infra/managed-login.md` for pricing, recreation and staged-downgrade notes. Do not reintroduce ephemeral sign-in just to choose another account while Managed Login is enabled.
