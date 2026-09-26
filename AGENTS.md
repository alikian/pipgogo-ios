# PipGoGo project context

## Project time tracking

- Maintain [TIME_LOG.md](TIME_LOG.md) as one project-wide log, mirrored identically in both repositories. Do not double-count cross-repository work or mirrored entries.
- For future work sessions, capture start/end timestamps and known pauses, record the contributor and milestone, and update duration totals after validation. Measured Codex session time is elapsed work time, not the user's labor hours. Do not create a scheduled automation for this.
- Keep recorded time separate from estimates and unknown historical time. If session boundaries were not captured, do not invent exact durations or infer them from Git/chat timestamps. Leave previous unmeasured work unrecorded until a sourced estimate is available.

## Progress at a glance

**[Readable roadmap](ROADMAP.md)** · **Next: 2.6 — Pre-trip check-in**

| Area | Current state |
| --- | --- |
| Authentication | Initial acceptance complete; upgraded iPhone account-chooser check pending |
| Basic trip flow | 2.1–2.5 implemented; 2.2–2.5 still need device acceptance |
| AI planning | 3.1–3.6 planned; no AI-generated trips in the app yet |
| Offline / production hosting | Not delivered; app uses the Mac's LAN backend |
| Latest checks | 85 iOS tests, 10 focused backend checks passed; signed iPhone build installed |

Update `ROADMAP.md` in both repositories with each milestone change. Keep implementation and
device acceptance statuses separate. Detailed requirements and historical checkpoints follow.

- Display the app name as `PipGoGo` in all user-facing UI, app display names, and documentation. Preserve lowercase `pipgogo` in existing technical identifiers, repository/project names, bundle IDs, URL schemes, domains, and infrastructure resource names.
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
- **Step 1 complete (September 25, 2026):** signed iPhone build and session restoration were agent-verified; sign-in, logout persistence and the 16-minute expiry/refresh test were user-confirmed. Agent-operated Chrome verified live refresh-token revocation (`invalid_grant` after a working baseline), B denied read/list/overwrite of A's trip, A's original trip unchanged, and test-trip soft deletion. Final browser test session signed out. See backend `docs/auth-verification.md` for evidence and limits. Steps 2.1–2.5 are implemented; profile, companion, and trip physical-device acceptance is pending. The next implementation milestone is 2.6, pre-trip check-in.

## Step 2 milestones — basic iOS trip flow

Implement these milestones sequentially and report each independently. Milestone 2.1 is complete. Milestone 2.2 is implemented with tests and a signed device installation; physical-device save/reopen/clear confirmation is pending. Milestone 2.3 is implemented with automated coverage; physical-device acceptance is pending. Milestone 2.4 is implemented with automated coverage; physical-device acceptance is pending. Milestone 2.5 editing/deletion is implemented with automated coverage; physical-device acceptance is pending. Milestones 2.6–2.8 have not started. Keep Step 1 authentication working throughout. The API contract is in the backend `docs/api.md`.

| Milestone | Scope | Completion check |
| --- | --- | --- |
| 2.1 — Completed: shared API client | Extend authenticated requests beyond account loading; decode records and structured errors; support expected versions, stable client UUIDs and idempotency keys. Retry the same operation with the same body/key/version, including after token refresh. Expose 409 details without automatically overwriting data. | Focused tests prove header/encoding behavior, retry identity, bounded authentication retry, and conflict/error decoding; existing auth tests still pass. |
| 2.2 — Implemented; device acceptance pending | Add profile navigation, initial empty state, load/edit/save optional preferences, and clearing optional values. Preserve the draft on errors; show a conflict and let the user review server data before choosing how to resolve it. | Save, reopen and edit on device; clearing values works; failed saves and conflicts retain the draft. |
| 2.3 — Implemented; device acceptance pending | List, create, edit and delete recurring companions using stable UUIDs. Explain deletion rejection when a companion belongs to an active trip. Reuse the profile milestone's save/conflict behavior. | Create/edit/delete a companion; verify an in-use companion cannot be deleted and local edits survive failed saves. |
| 2.4 — Implemented; device acceptance pending | Add empty/list/detail navigation and a new-trip form for destination, optional dates, accommodation and selected companions. Preserve supported fields when serializing replacement writes. | Create a trip, navigate away and reload it with its selected companions; a retried creation cannot create a duplicate trip. |
| 2.5 — Implemented; device acceptance pending | Edit existing trip context and optional fields; validate dates and other API constraints. Present version conflicts without losing the draft; require deliberate resolution before retrying against a newer version. Explain soft deletion and confirm before deleting. | Edit and reload; simulate a concurrent edit and resolve it; delete removes the trip from the active list without claiming permanent history erasure. |
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
- Implementation/acceptance guide: iOS `docs/traveler-profile.md`. Milestone 2.3 (companions) is now implemented; see the result below.

Full offline outbox/sync, durable offline package storage and automatic conflict merging remain Step 4. Live AI and verified travel guidance remain Step 3. Milestones 2.1–2.7 must still handle errors and conflicts correctly in their online flows; do not defer basic retry safety or preserving an open draft.

## Account selection — current configuration

The private-browser workaround was superseded by an in-place CloudFormation upgrade to Essentials and Managed Login v2. `EnableManagedLogin=true` selects this configuration and creates default mobile-client branding. Both custom/prefix domains forward `prompt=select_account` to Google. iOS explicitly requests that prompt and uses `prefersEphemeral: false`, allowing the browser account chooser. Accounts present only in the Gmail app may not appear in this browser session.

CloudFormation reached UPDATE_COMPLETE without resource replacements; pool/client IDs and the issuer are unchanged. Chrome chooser, Google sign-in/code exchange/backend access and browser refresh/revocation/logout were checked after upgrade. All 42 iOS tests passed; the signed build was installed on the connected iPhone. Physical-iPhone chooser confirmation and profile milestone 2.2 device acceptance remain pending.

See backend `infra/managed-login.md` for pricing, recreation and staged-downgrade notes. Do not reintroduce ephemeral sign-in just to choose another account while Managed Login is enabled.

## Milestone 2.3 implementation — September 26, 2026

- PipGoGo account navigation now opens Companions: list, create, edit/clear optional details and preferences, and confirmed deletion. Uses existing authenticated backend endpoints; no API or infrastructure changes were needed.
- Client-generated UUIDs and immutable requests preserve identity on retries. Uncertain writes freeze editing until resolved. Version conflicts preserve drafts and require review; accepting saved state requires confirmation. A remotely deleted companion can only be copied to a new UUID by an explicit user choice.
- In-use deletion explains active-trip protection. Deletion handles empty-data tombstones and removes list rows without promising permanent history erasure. Session-owned drafts survive navigation; sign-out cancels/resets work and ignores late responses.
- Verification: **57 iOS tests passed** (42 prior plus 15 companion state/service cases); backend companion-in-use tests passed with memory and Moto-backed DynamoDB (**2 passed**). Mocked tests do not prove live device acceptance.
- Signed Debug iPhone build passed and was installed on the connected iPhone 12. The bundled PipGoGo display name and app-icon configuration are preserved.
- Physical-device companion CRUD/account switching and the earlier profile save/reopen/clear check remain pending. See iOS `docs/companions.md` for acceptance instructions and limitations. Milestone 2.4 is now implemented; see its checkpoint below. Next implementation milestone: **2.6 — pre-trip check-in**.

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
- Physical-device trip create/reopen/companion selection/account switching acceptance remains pending, alongside earlier profile/companion acceptance. See iOS `docs/trips.md`. Next implementation milestone: **2.6 — pre-trip check-in**. AI planning remains a separate planned Step 3 feature.

## Milestone 2.5 implementation — September 26, 2026

- Saved trips now offer Edit and confirmed Delete. Editable context includes destinations, dates, accommodation/reservation reference, companions, transportation, itinerary, constraints, and trip preferences. Full replacement writes preserve other saved fields, including flights, lodging check-in timestamps, and exact budget values.
- One session-owned draft survives navigation; uncertain operations retain their exact request/key/version. Conflict screens offer draft/saved review, deliberate rebasing followed by a separate Save, or confirmed use of saved state. Deleted identities can only be copied to a new UUID by explicit choice.
- Deletion requires a clean draft and confirmation, handles empty-data tombstones, and removes the trip from the active list. Conflict resolution never automatically repeats deletion. The UI explains retained history; known deletions prevent stale receipts from restoring rows. Sign-out cancels/resets deletion and ignores late responses.
- Verification: **85 iOS tests passed** and **10 backend regressions passed** with memory/Moto DynamoDB. No API or infrastructure changes were required. Physical-device editing/conflict/deletion acceptance remains pending, as do earlier unconfirmed device checks. See iOS `docs/trips.md`.
- Signed Debug build passed and was installed on the connected iPhone 12. The LAN backend reported ready with Cognito and DynamoDB.
- Next implementation milestone: **2.6 — pre-trip check-in**. AI planning and durable offline storage remain separate Step 3 and Step 4 work.

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
