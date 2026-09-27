# PipPipGo project context

## Project time tracking

- Maintain [TIME_LOG.md](TIME_LOG.md) as one project-wide log, mirrored identically in both repositories. Do not double-count cross-repository work or mirrored entries.
- For future work sessions, capture start/end timestamps and known pauses, record the contributor and milestone, and update duration totals after validation. Measured Codex session time is elapsed work time, not the user's labor hours. Do not create a scheduled automation for this.
- Keep recorded time separate from estimates and unknown historical time. If session boundaries were not captured, do not invent exact durations or infer them from Git/chat timestamps. Leave previous unmeasured work unrecorded until a sourced estimate is available.

## Progress at a glance

**[Readable roadmap](ROADMAP.md)** · **Next: 5.2a — Hosted Dev device acceptance**

| Area | Current state |
| --- | --- |
| Authentication | Initial acceptance complete; upgraded iPhone account-chooser check pending |
| Basic trip flow | 2.1–2.6 implemented; 2.2–2.6 still need device acceptance |
| AI planning | 3.1–3.6 planned; no AI-generated trips in the app yet |
| Offline / hosting | Dev API deployed on standard ECS Fargate; device acceptance, Prod and offline remain |
| Latest checks | 110 Local iOS tests; 7 configuration checks each for Dev/Prod; three signed builds passed. Backend: 56 passed, 1 skipped; Dev deployment and rolling update passed |

Update `ROADMAP.md` in both repositories with each milestone change. Keep implementation and
device acceptance statuses separate. Detailed requirements and historical checkpoints follow.

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


## Authentication verification checkpoint — September 25, 2026

- Historical September 25 verification: a signed Debug build was installed and launched on the connected iPhone 12 using the former sign-in domain `https://auth.pipgogo.com` and the LAN backend at `http://192.168.0.156:8765`. Verify the Mac address and server availability on later runs.
- Fixed duplicate OAuth callback parameters crashing the parser and literal `+` handling in OAuth form bodies. The networking test suite is serialized because its mock URLProtocol uses shared response state.
- All 15 simulator tests passed, including callback/state/PKCE, code exchange, refresh, revocation request and account response checks. These mocked tests do not prove live Google sign-in or revocation.
- **Step 1 complete (September 25, 2026):** signed iPhone build and session restoration were agent-verified; sign-in, logout persistence and the 16-minute expiry/refresh test were user-confirmed. Agent-operated Chrome verified live refresh-token revocation (`invalid_grant` after a working baseline), B denied read/list/overwrite of A's trip, A's original trip unchanged, and test-trip soft deletion. Final browser test session signed out. See backend `docs/auth-verification.md` for evidence and limits. Steps 2.1–2.6 are implemented; profile, companion, and trip physical-device acceptance is pending. The next work milestone is 5.2a, hosted Dev environment; the next product feature remains 2.7.

## Step 2 milestones — basic iOS trip flow

Implement these milestones sequentially and report each independently. Milestone 2.1 is complete. Milestone 2.2 is implemented with tests and a signed device installation; physical-device save/reopen/clear confirmation is pending. Milestone 2.3 is implemented with automated coverage; physical-device acceptance is pending. Milestone 2.4 is implemented with automated coverage; physical-device acceptance is pending. Milestone 2.5 editing/deletion is implemented with automated coverage; physical-device acceptance is pending. Milestone 2.6 is implemented; physical-device acceptance is pending. Milestones 2.7–2.9 have not started. Keep Step 1 authentication working throughout. The API contract is in the backend `docs/api.md`.

| Milestone | Scope | Completion check |
| --- | --- | --- |
| 2.1 — Completed: shared API client | Extend authenticated requests beyond account loading; decode records and structured errors; support expected versions, stable client UUIDs and idempotency keys. Retry the same operation with the same body/key/version, including after token refresh. Expose 409 details without automatically overwriting data. | Focused tests prove header/encoding behavior, retry identity, bounded authentication retry, and conflict/error decoding; existing auth tests still pass. |
| 2.2 — Implemented; device acceptance pending | Add profile navigation, initial empty state, load/edit/save optional preferences, and clearing optional values. Preserve the draft on errors; show a conflict and let the user review server data before choosing how to resolve it. | Save, reopen and edit on device; clearing values works; failed saves and conflicts retain the draft. |
| 2.3 — Implemented; device acceptance pending | List, create, edit and delete recurring companions using stable UUIDs. Explain deletion rejection when a companion belongs to an active trip. Reuse the profile milestone's save/conflict behavior. | Create/edit/delete a companion; verify an in-use companion cannot be deleted and local edits survive failed saves. |
| 2.4 — Implemented; device acceptance pending | Add empty/list/detail navigation and a new-trip form for destination, optional dates, accommodation and selected companions. Preserve supported fields when serializing replacement writes. | Create a trip, navigate away and reload it with its selected companions; a retried creation cannot create a duplicate trip. |
| 2.5 — Implemented; device acceptance pending | Edit existing trip context and optional fields; validate dates and other API constraints. Present version conflicts without losing the draft; require deliberate resolution before retrying against a newer version. Explain soft deletion and confirm before deleting. | Edit and reload; simulate a concurrent edit and resolve it; delete removes the trip from the active list without claiming permanent history erasure. |
| 2.6 — Implemented; device acceptance pending | Show current trip context, capture requests/concerns, and confirm the current trip version. Clearly report unavailable live travel data and require reconfirmation after a trip change. | Save/reopen a check-in; an intervening trip edit cannot silently confirm stale context. |
| 2.7 — Partial companion package | Generate, list and display package editions; authenticate JSON download and show saved trip information, creation time and missing guidance. Explain privacy implications and make optional profile/companion/reservation inclusion explicit. | Generate after a valid check-in; retry yields the same edition; download/display works and partial/unavailable content is clearly labeled. Durable offline storage remains Step 4. |
| 2.8 — Integrated acceptance | Use Appium milestones 2.8a–2.8c below to exercise profile → companions → trip → edit → check-in → package on the physical iPhone. Check account switching, error recovery and existing sign-in/refresh/logout. Record device results separately from mocked tests. | Complete the journey with the real development backend; record results and limitations, then accept the core trip flow; milestone 2.9 has separate import acceptance. |

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
- Implementation/acceptance guide: iOS `docs/traveler-profile.md`. Milestone 2.3 (companions) is now implemented; see the result below.

Full offline outbox/sync, durable offline package storage and automatic conflict merging remain Step 4. Live AI and verified travel guidance remain Step 3. Milestones 2.1–2.7 must still handle errors and conflicts correctly in their online flows; do not defer basic retry safety or preserving an open draft.

## Account selection — current configuration

The private-browser workaround was superseded by an in-place CloudFormation upgrade to Essentials and Managed Login v2. `EnableManagedLogin=true` selects this configuration and creates default mobile-client branding. Both custom/prefix domains forward `prompt=select_account` to Google. iOS explicitly requests that prompt and uses `prefersEphemeral: false`, allowing the browser account chooser. Accounts present only in the Gmail app may not appear in this browser session.

CloudFormation reached UPDATE_COMPLETE without resource replacements; pool/client IDs and the issuer are unchanged. Chrome chooser, Google sign-in/code exchange/backend access and browser refresh/revocation/logout were checked after upgrade. All 42 iOS tests passed; the signed build was installed on the connected iPhone. Physical-iPhone chooser confirmation and profile milestone 2.2 device acceptance remain pending.

See backend `infra/managed-login.md` for pricing, recreation and staged-downgrade notes. Do not reintroduce ephemeral sign-in just to choose another account while Managed Login is enabled.

## Milestone 2.3 implementation — September 26, 2026

- PipPipGo account navigation now opens Companions: list, create, edit/clear optional details and preferences, and confirmed deletion. Uses existing authenticated backend endpoints; no API or infrastructure changes were needed.
- Client-generated UUIDs and immutable requests preserve identity on retries. Uncertain writes freeze editing until resolved. Version conflicts preserve drafts and require review; accepting saved state requires confirmation. A remotely deleted companion can only be copied to a new UUID by an explicit user choice.
- In-use deletion explains active-trip protection. Deletion handles empty-data tombstones and removes list rows without promising permanent history erasure. Session-owned drafts survive navigation; sign-out cancels/resets work and ignores late responses.
- Verification: **57 iOS tests passed** (42 prior plus 15 companion state/service cases); backend companion-in-use tests passed with memory and Moto-backed DynamoDB (**2 passed**). Mocked tests do not prove live device acceptance.
- Signed Debug iPhone build passed and was installed on the connected iPhone 12. The bundled PipPipGo display name and app-icon configuration are preserved.
- Physical-device companion CRUD/account switching and the earlier profile save/reopen/clear check remain pending. See iOS `docs/companions.md` for acceptance instructions and limitations. Milestone 2.4 is now implemented; see its checkpoint below. Next implementation milestone: **5.2a — hosted Dev environment**.

- Language preferences in the traveler profile and companion editor use a simple single-selection dropdown with a Not set option. Keep the backend string-array format: a new selection writes one value, clearing writes an empty array. Existing custom values remain selectable; legacy multiple values are not rewritten merely by viewing the form.

## Added requirement — AI-assisted trip creation

- Support natural-language trip planning, for example “Create a 10-day trip for Japan. We are OK with flying from LAX.” Generate an editable day-by-day draft, clarify material unknowns, allow conversational refinement, and explicitly save the approved plan as one trip in the trip list.
- Treat LAX as an acceptable departure airport, not a booked flight. Preserve duration and departure preferences; distinguish assumptions/suggestions from sourced live travel facts. Use only the profile/companions the traveler chooses to include.
- Canonical details and acceptance criteria: backend `docs/ai-trip-planning.md`. Status: planned, not implemented. Milestone 2.4 provides the trip-list/manual-creation foundation; implement AI planning with Step 3 provider work after defining the required planning/trip schema. The San Diego live-guidance pilot remains unchanged.

## Milestone 2.4 implementation — September 26, 2026

- Account navigation now opens Trips: empty/list/detail states and manual creation with destinations, optional calendar dates/accommodation, and selected companions. Successful saves return to the updated list. Details refresh from the existing API; missing/deleted trips leave the list.
- Models preserve every current backend trip-body field. Creation retains its UUID, version zero, encoded body, and key for safe retries. Conflicts never silently overwrite an existing trip; a separate-copy decision uses a new UUID. Missing companion rejection is recoverable without losing the draft.
- Session drafts survive navigation, and sign-out cancels/resets work. Late reads/writes cannot restore the previous account's state; replayed receipts do not replace newer fetched trips. Durable offline persistence remains Step 4.
- Verification: **73 iOS tests passed** (57 prior plus 16 trip model/state/service cases), and **6 backend regression cases passed** across memory and Moto-backed DynamoDB. No API or AWS changes were required.
- Signed Debug build passed and was installed on the connected iPhone 12. The LAN backend reported ready with Cognito and DynamoDB.
- Physical-device trip create/reopen/companion selection/account switching acceptance remains pending, alongside earlier profile/companion acceptance. See iOS `docs/trips.md`. Next implementation milestone: **5.2a — hosted Dev environment**. AI planning remains a separate planned Step 3 feature.

## Milestone 2.5 implementation — September 26, 2026

- Saved trips now offer Edit and confirmed Delete. Editable context includes destinations, dates, accommodation/reservation reference, companions, transportation, itinerary, constraints, and trip preferences. Full replacement writes preserve other saved fields, including flights, lodging check-in timestamps, and exact budget values.
- One session-owned draft survives navigation; uncertain operations retain their exact request/key/version. Conflict screens offer draft/saved review, deliberate rebasing followed by a separate Save, or confirmed use of saved state. Deleted identities can only be copied to a new UUID by explicit choice.
- Deletion requires a clean draft and confirmation, handles empty-data tombstones, and removes the trip from the active list. Conflict resolution never automatically repeats deletion. The UI explains retained history; known deletions prevent stale receipts from restoring rows. Sign-out cancels/resets deletion and ignores late responses.
- Verification: **85 iOS tests passed** and **10 backend regressions passed** with memory/Moto DynamoDB. No API or infrastructure changes were required. Physical-device editing/conflict/deletion acceptance remains pending, as do earlier unconfirmed device checks. See iOS `docs/trips.md`.
- Signed Debug build passed and was installed on the connected iPhone 12. The LAN backend reported ready with Cognito and DynamoDB.
- Next implementation milestone: **5.2a — hosted Dev environment**. AI planning and durable offline storage remain separate Step 3 and Step 4 work.

- Trip details refresh automatically when opened, when the app becomes active, and when the editor closes. Keep the manual circular refresh button removed; automatic reads must preserve drafts and never submit mutations.

## Step 3 milestones — AI trip planning and travel guidance

All milestones below are **planned, not implemented**. Follow Step 2's basic trip flow with
these milestones in order. Manual trip creation does not count as AI trip generation.
The full planning requirement is in backend `docs/ai-trip-planning.md`.

| Milestone | Scope | Completion check |
| --- | --- | --- |
| 3.1 — AI provider and planning contract | Connect a server-side AI provider; define planning input, clarification, and structured itinerary responses plus trip-schema additions for duration, departure airport, assumptions, and daily activities. Set timeouts, cost limits, and error handling. | Backend tests validate structured output and failure paths; provider credentials remain outside the app and Git. |
| 3.2 — Plan with AI | Add a visible Plan with AI entry on the Trips screen. Accept natural-language requests, ask necessary follow-up questions, and display the generated daily itinerary. Include optional profile and selected companions by explicit choice. | “Create a 10-day trip for Japan; we are OK flying from LAX” produces a reviewable plan that respects Japan, duration, and departure preference, with unknowns clarified or assumptions shown. |
| 3.3 — Review and refine | Allow direct edits and conversational changes such as “less walking” or “include Kyoto.” Keep user constraints, selected travelers, and manual changes when revising. | Refinement updates the draft without losing constraints or silently replacing a saved trip; failures retain recoverable input. |
| 3.4 — Save AI-generated trips | Save the approved structured plan as one trip in the existing list; display and reopen its daily itinerary. Apply the existing ownership, version-conflict, and idempotency rules. | Save returns to the list; reopening retains the approved plan; a lost response and retry cannot create duplicate trips. |
| 3.5 — AI planning acceptance | Exercise prompt → clarification → generation → refinement → save → reopen on the physical iPhone. Check provider/network failures and account isolation. | Record real device/provider results, including the Japan/LAX example. Suggestions, estimates, and sourced facts are distinguishable; nothing is presented as a booking. |
| 3.6 — Verified San Diego guidance | Connect authoritative airport/transport/place data and deliver the original arrival-guidance pilot with sources, freshness, essential phrases, and unavailable-data behavior. | Verify the airport-to-accommodation journey separately from itinerary generation; unverified live facts are not invented. |

Offline generation is not included. Durable offline access to saved plans remains Step 4.

## Appium device testing — milestone 2.8

Appium is the agreed tool for physical-iPhone UI automation. Setup and tests are **planned,
not installed or verified yet**. Keep existing unit/service tests; Appium adds real-device
acceptance evidence. The next product feature is 2.7, partial companion package. Start Appium
setup before the integrated acceptance run, and cover existing screens as soon as it works.

| Milestone | Scope | Completion check |
| --- | --- | --- |
| 2.8a — Appium setup | Configure local Appium, its XCUITest driver and signed WebDriverAgent on the development Mac and designated iPhone. Document reproducible setup, device selection and run commands in the iOS repository. | Launch PipPipGo, inspect UI elements, tap/type and capture a screenshot on the physical iPhone. No paid cloud testing service is required. |
| 2.8b — Existing-screen regression tests | Add stable accessibility identifiers where needed and repeatable profile, companion and trip create/edit/delete tests; include validation, conflict recovery and account switching. | Run against the development backend with dedicated test records; save pass/fail results and screenshots, and clean up test records without touching personal trips. Record manual Google sign-in/verification steps separately. |
| 2.8c — Integrated acceptance | Extend the suite to check-in and packages once 2.6–2.7 are built, and later AI planning (3.5) and offline use (Step 4). | Record the complete physical-device journey with app/build/device/backend details; distinguish automated, manual, skipped and blocked checks before accepting a milestone. |

Reference: [Appium XCUITest driver](https://appium.github.io/appium-xcuitest-driver/).

## 5.1 · Automated release versioning

**Status: ○ Planned.** Git/GitHub source control already exists. This milestone adds release
versioning before automated deployment and TestFlight distribution. Backend and iOS versions
remain independent; the next product feature is 2.7, partial companion package.

| Part | Scope | Completion check |
| --- | --- | --- |
| 5.1a — Version policy | Define independent major.minor.patch release versions, including pre-1.0 breaking-change rules, and a single version source per repository. Classify release changes with `fix:`, `feat:` and explicit breaking-change markers. Keep release versions distinct from API `/v1` and record versions. | Document examples for fixes, features and breaking changes; version sources agree with packaged application metadata. |
| 5.1b — Release PR automation | Use GitHub Actions to prepare version bumps and changelogs in release PRs. Require passing checks and deliberate approval before merging; create immutable Git tags and GitHub releases from the approved commit. | Demonstrate a release PR and tag with matching version/commit; repeated workflow runs cannot duplicate a release or move an existing tag. |
| 5.1c — Build identity and delivery | Assign monotonically increasing iOS build numbers; stamp app version/build and source commit into artifacts. Identify backend images by version, commit and immutable digest. Connect approved releases to deployment/TestFlight workflows when available. | Concurrent runs and retries cannot reuse a build number for different uploads; artifacts and test reports identify the exact backend and iOS versions/commits tested together. |
| 5.1d — Compatibility and recovery | Preserve compatibility with older installed apps; document backend rollback to a previously tested image and iOS recovery through a new build/release. | Rehearse a release and backend rollback in staging; record compatibility results and retain the release artifacts needed for recovery. |

Versioning automation is not implemented yet. Hosting, signing/upload credentials and CI checks
are separate prerequisites for delivery; adding this milestone does not enable publishing.

## PipPipGo rename — September 26, 2026

- App UI, Debug/Release display names, backend API title, login harness and documentation now use PipPipGo. Technical identities remain stable.
- Validation: 85 iOS simulator tests passed; built Debug bundle reports PipPipGo. Backend: 42 passed, 1 skipped; Ruff lint/format passed. The signed new-domain build was subsequently installed and launched on the connected iPhone 12.
- The approved CloudFormation cutover completed: auth.pippipgo.com is ACTIVE, foundation UPDATE_COMPLETE, original pool/client/table preserved. Google sign-in, backend access, refresh, revocation and logout passed in Chrome. The user confirmed sign-in works on the updated iPhone build on September 26, 2026. Repeat device restoration, expiry/refresh and logout checks remain pending. See backend infra/pippipgo-migration.md.

## 5.2 · Backend deployment

**Status: ○ Planned.** Deploy a hosted HTTPS API so PipPipGo works without the Mac's LAN
backend. Start with hosted Dev setup (5.2a); use release versioning (5.1) for
automated delivery before TestFlight distribution and traveler testing.
The next product feature is 2.7, partial companion package.

| Part | Scope | Completion check |
| --- | --- | --- |
| 5.2a — Hosted Dev environment (next) | Deploy `https://dev.pippipgo.com` through CloudFormation with HTTPS, runtime IAM, monitoring and defined data/authentication boundaries; preserve existing identities and retained data. | Dev build completes authentication and trip/check-in acceptance on a physical phone with the Mac backend stopped; record deployment, isolation and rollback evidence. |
| 5.2b — Deployment pipeline | Add GitHub Actions tests, Ruff lint/format and container validation. Use short-lived AWS credentials; publish versioned images and deploy by immutable digest from 5.1. Validate in staging before approved production promotion. | A release deploys the tested image; failed checks block promotion, secrets stay outside Git/images, and reruns do not deploy a different artifact under the same version. |
| 5.2c — Hosted API and iOS integration | Configure production Cognito/DynamoDB access and a dedicated HTTPS API URL; update iOS release configuration and restrict development-only settings/callbacks appropriately. Keep the sign-in domain migration separate. | A physical iPhone on cellular or another network completes sign-in, refresh, logout and the implemented trip flow with the Mac backend stopped; record app/backend versions and account-isolation results. |
| 5.2d — Operations and recovery | Add monitoring, actionable alerts, traffic/cost limits and log retention without exposing tokens or travel data. Validate real DynamoDB concurrency, interrupted account deletion, retention/per-trip erasure requirements and backup recovery; document rollback. | Exercise alerts and recovery in staging, roll back to a tested image without losing retained data, and record operational evidence before traveler testing. |

Application hosting is not deployed yet. Record infrastructure deployment and end-to-end
acceptance separately. Backend `docs/deployment.md` will hold the selected service, API URL,
run commands and deployment evidence as this milestone is implemented.

## GitHub repository rename — September 26, 2026

- GitHub repositories are `alikian/pippipgo-backend` and `alikian/pippipgo-ios`; local origin remotes use those URLs.
- Local checkout directories are now `/Users/alikianzadeh/git/pippipgo-backend` and `/Users/alikianzadeh/git/pippipgo-ios`. The folders were renamed after the GitHub repositories. Old `pipgogo-backend` and `pipgogo-ios` paths are compatibility symlinks for existing sessions and the backend environment. The Xcode project name remains unchanged.

## 5.3 · Public website — pippipgo.com

**Status: ○ Planned.** Create a public PipPipGo website at `https://pippipgo.com`
to explain the product and help travelers find support and the app. The next product
feature is 2.7, partial companion package. Website delivery is separate from the hosted
backend API (5.2) and the existing `auth.pippipgo.com` sign-in service.

| Part | Scope | Completion check |
| --- | --- | --- |
| 5.3a — Content and page scope | Define a concise homepage explaining the traveler journey, current features and availability; include support/contact and privacy information. Add TestFlight/App Store links when distribution is available. Clearly distinguish planned AI/offline capabilities from released features. | Review page copy, destinations and support details; no placeholder download links or unsupported product claims. |
| 5.3b — Design and implementation | Build a responsive, accessible site with PipPipGo branding, readable mobile layouts, clear navigation and basic search/social metadata. Keep the first release focused on public product information. | Verify mobile/desktop layouts, keyboard navigation, contrast, page titles and working links; document the website source and build commands. |
| 5.3c — Hosting, HTTPS and DNS | Select hosting and a reproducible deployment workflow. Manage AWS infrastructure through CloudFormation if AWS is selected. Configure apex/www routing and TLS; coordinate replacement of the root placeholder A record with `pippipgo-auth-certificate`. Preserve Cognito's parent-domain DNS requirement, `auth.pippipgo.com`, certificate validation records and any mail records. | Public HTTPS serves the site at pippipgo.com with a consistent www redirect; certificate renewal is configured, and Google/iPhone sign-in still works after DNS changes. |
| 5.3d — Launch and maintenance | Review final content, verify support/privacy links, check performance and deployment rollback, then publish the approved site. Add app download links only when their destinations are live. | Record the deployed version, public URL, mobile/desktop checks and authentication regression results; demonstrate rollback to a known working site. |

The root domain currently has a Cognito prerequisite placeholder, not a website.
This milestone records planned work only; it does not deploy a site or change DNS.
A web trip-planning/account application and collection of waitlist/contact-form data
require separately defined scope before implementation.


## Milestone 2.6 implementation — September 26, 2026

- Saved trip details now open Pre-trip check-in: review full trip context, capture optional requests/concerns, explicitly confirm the current trip version, save and reopen. Changed trips require fresh review and confirmation; the server rejects stale trip versions.
- Session-owned per-trip drafts survive navigation. Uncertain saves retain the exact body/key/check-in version. Changed check-ins require local/saved note review and deliberate resolution followed by a separate save. Successful receipt replay reloads current state before claiming confirmation is current.
- Missing/read-failed trips cannot be confirmed. Sign-out cancels work, clears notes and ignores late responses. Live travel data remains unavailable, with warnings and missing categories shown. No package generation or durable offline storage was added.
- Validation: **103 iOS tests passed**; **48 backend tests passed, 1 skipped**, including six new memory/Moto check-in regressions; Ruff lint/format passed. Signed Debug iPhone build passed and was installed/launched on the designated iPhone 12. The LAN backend reported ready with Cognito/DynamoDB. No API or infrastructure changes were required.
- Physical-device save/reopen/clear, stale-version/conflict handling and account switching acceptance remain pending, alongside earlier device checks. See iOS `docs/check-ins.md`. Mocked tests and installation are not device acceptance.
- Next implementation milestone: **5.2a — hosted Dev environment**.


## 2.9 · Trip input from Photos, camera and Files

**Status: ○ Planned, not implemented.** Import trip details from screenshots/photos
selected through Photos, camera capture, or documents selected through Files. Files
imports accept **PDF (.pdf) and DOCX (.docx) only**; other document formats are
unsupported. Photos and camera continue to accept images. Example inputs include
flight confirmations, hotel reservations and itineraries. Schedule after the basic-flow acceptance milestone (2.8);
the next work milestone is **5.2a — hosted Dev environment**; the next product feature remains **2.7 — partial companion package**.

| Part | Scope | Completion check |
| --- | --- | --- |
| 2.9a — Photos, camera and Files input | Add Import trip details with user-selected Photos access, camera capture and a Files picker restricted to PDF and DOCX. Validate file content/type as well as extension; reject other formats with a clear message. Provide source preview, image crop/rotate, camera retake and cancel. Handle limited/denied Photos access, unavailable camera and inaccessible files without losing the current trip draft. | On a physical iPhone, select a screenshot/photo, capture a reservation photo, and import a PDF and a DOCX from Files. Unsupported or mislabeled files are rejected; preview/cancel/retake and access-failure recovery work. |
| 2.9b — Extract trip fields | Extract text from images, PDFs (including scanned pages) and DOCX documents, and map available destinations, dates, flight numbers/airports/times, accommodation names/addresses and reservation references into an editable draft. Show the source image/document text alongside extracted values; flag unclear dates, time zones and unreadable/missing fields instead of guessing. Select on-device OCR or a server/provider approach during implementation; explain any image/document upload before it occurs and define retention/deletion. Treat imported text as data, never instructions to execute. | Representative flight, hotel and itinerary images, PDFs and DOCX files produce reviewable fields. Blurred, cropped, ambiguous or unreadable content remains explicitly unresolved; corrupt/password-protected documents fail recoverably. Source files and extracted private data are not included in diagnostic logs. |
| 2.9c — Review and save | Let the traveler correct fields and explicitly choose a new trip or selected updates to an existing trip. Show proposed changes, preserve unrelated/manual fields, and require approval before saving. Reuse ownership, validation, version-conflict and idempotency rules; repeated input must not silently create duplicates. | Correct an extracted date, save and reopen; existing trip fields are preserved unless selected for replacement. A lost response and retry cannot duplicate a trip; concurrent edits require deliberate resolution. Changes to confirmed trip context require a new check-in. |
| 2.9d — Device acceptance | Test Photos, camera, PDF and DOCX flows end to end with dedicated sample reservations, plus poor images, scanned PDFs, unsupported/mislabeled formats, corrupt/password-protected documents, limited/denied access, cancellation, extraction/network failures, duplicate input and account switching. Extend Appium coverage where supported and record manual camera steps separately. | Record actual device/extraction results for flight and hotel inputs across Photos, camera, PDF and DOCX: capture/select → extract → review/correct → save → reopen. Separate automated, manual, skipped and blocked checks before accepting the milestone. |

Imported details are traveler-supplied information, not independently verified live
travel facts. Automatic email/calendar connections and continuous screen recording
are outside this milestone. Durable offline import queues remain Step 4; raw image/document
storage is not a requirement for saving the approved structured trip details.

## Local, Dev and Prod app builds — September 26, 2026

- Shared Xcode schemes/configurations are now `Local`, `Dev`, `Prod`; the former `pipgogo` scheme and Debug/Release configuration names are replaced. The project, target, module, bundle ID and native OAuth callbacks retain their configured identities.
- Local targets localhost on Simulator and the Mac LAN backend on device. Dev targets `https://dev.pippipgo.com`; Prod targets `https://pippipgo.com`. Dev/Prod require HTTPS with no Local HTTP exceptions or automatic fallback. Select a scheme and rebuild to switch; every scheme uses its own configuration for Run and Archive.
- All builds keep bundle ID `com.pipgogo.ios`, so installation replaces the existing variant. Display names distinguish Local and Dev; Prod displays PipPipGo. Keychain token services are separate per environment; Local preserves its existing service for session continuity.
- Cognito settings are configurable through `Configurations/*.xcconfig` and currently share the existing foundation. Build selection does not establish separate backend databases or user pools. Hosted Dev/Prod APIs, identity/data isolation and end-to-end device acceptance remain milestone 5.2.
- Production routing must send `/v1/*` on pippipgo.com to the API while website paths serve milestone 5.3. No AWS, DNS, OAuth or production hosting changes were made. See iOS `docs/environments.md` for configuration and commands. Next product milestone remains 2.7.
- Validation: 110 Local simulator tests passed; 7 configuration tests each passed under Dev and Prod (Prod test build explicitly enabled testability). Signed device builds passed for all three variants; bundled URLs/names/HTTP policy and scheme Run/Archive mappings were verified. Hosted API/device acceptance is still pending; the new variants were built, not installed during this session.


### 5.2a — Next: hosted Dev environment

**Status: ○ Planned, not deployed.** This is the next work milestone, before returning
to product milestone 2.7. Deliver a usable HTTPS API at `https://dev.pippipgo.com`
for the Dev app build, so testing no longer requires the Mac backend.

1. Select AWS hosting and define region, cost limits and the Dev data/authentication
   boundary. Document whether Local shares Dev data; keep future production data
   separate and preserve existing Cognito identities and retained DynamoDB records.
2. Add reproducible CloudFormation for the container runtime, image registry,
   least-privilege runtime IAM, HTTPS certificate and Route 53 record. Preserve
   `auth.pippipgo.com`, apex website planning, certificate validation and mail DNS.
3. Deploy a traceable backend image, configure Cognito/DynamoDB, and verify public
   `/health`, `/ready` and authenticated `/v1/me`. Add useful logs, monitoring and
   a documented redeploy/rollback command without exposing tokens or trip details.
4. Verify the Dev build shows **Build: Dev**, calls the hosted API and uses the
   matching authentication settings. Run sign-in, refresh, logout, account isolation
   and the implemented trip/check-in flow on a physical iPhone using cellular or
   another network, with the Mac backend stopped.

Completion requires recorded deployment and physical-device evidence, not merely
DNS resolution or a successful app build. Initial Dev deployment may use documented
manual commands; automated release/version/promotion work remains 5.1 and 5.2b.
Production hosting at `https://pippipgo.com` remains a later deployment step.

The app now shows its configured build environment (Local, Dev or Prod) in an accessible footer across root sign-in, account and navigation states. The label reflects the build configuration; it does not claim the remote API is deployed or healthy.

Environment indicator validation: 110 Local simulator tests passed; Local/Dev/Prod signed builds passed. The Local sign-in footer was visually verified in Simulator. Updated Local installed on Ali’s iPhone 12; automatic launch was blocked because the device was locked. Hosted Dev setup remains planned, with no AWS/DNS changes in this session.

## Hosting decision — September 27, 2026

Use standard ECS Fargate for the API. Backend `infra/persistence.yaml` replaces the
foundation filename only; preserve deployed `pipgogo-dev-foundation` and retained
resources. `delivery.yaml` manages ECR/OIDC/roles; `hosting.yaml` manages the runtime.
Use `develop` as the default branch, deploy backend develop to Dev and main to Prod.
Local and Dev share current development data/authentication. Production requires
separate persistence/auth and coordinated apex DNS ownership before enabling delivery.
See backend `infra/hosting.md`; live deployment/device evidence must be recorded separately.

Dev deployment succeeded September 27, 2026 via GitHub Actions run `36302023179`,
commit `41edf53`. ECS service `pippipgo-dev/backend` uses an immutable image digest.
HTTPS readiness/auth rejection passed; physical-device acceptance remains separate.
Both repositories now default to `develop`; `main` remains the production promotion branch.

Hosted Dev browser verification passed: real Cognito account access, trip creation,
two-account read/list/overwrite isolation, original-record verification/soft cleanup,
and refresh/revocation/logout. See backend `docs/hosting-verification.md` for DNS
workaround and physical-device evidence boundaries. The Mac LAN backend is stopped.
