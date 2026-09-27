# Traveler intelligence — implementation and delivery

The [source requirements](traveler-intelligence-requirements.md) replace the old questionnaire,
check-in and companion-package product sequence. Pip understands the trip, gets to know the
traveler, suggests a light plan, learns during the current journey and proposes adaptations.
**Pip never overplans.**

## Rebuilt source

The new iPhone product screens provide progressive trip intake, a Pip conversation, trip details,
import review, an accepted plan plus proposed changes, and traveler memory controls. The old
profile/companion/trip/check-in screens are removed from the target and recoverable through Git.
Google/Cognito authentication, PKCE, Keychain, refresh/revocation and account loading are retained.

The API replaces legacy product routes with journeys, memory, travelers, preferences, actions and
imports. Existing DynamoDB transaction/version/idempotency semantics, account ownership, export,
delete fence and ECS architecture remain. New product records use separate kinds; existing legacy
records are retained without being reinterpreted or deleted. No deployed data migration occurred.

A journey is a versioned aggregate containing intake, accepted optional plan, pending proposal,
conversation, temporary context, feedback and imports. Fixed commitments and confirmed import
facts are separate inputs to the planner. The provider can only propose optional suggestions.
Accept/reject requires the current proposal ID and journey version; intake changes invalidate
pending proposals. Confirmed import facts require traveler review/edit/acceptance first.

Memory has explicit/confirmed/inferred status, confidence, source, original text, timestamps and
persistent/trip-specific scope. Conversation output can atomically remember, correct or forget scoped memory alongside the
journey write. Existing IDs are required for correction/forgetting; temporary observations and
sensitive inferences are excluded. Explicit memory controls remain available.
Temporary feedback never automatically becomes persistent memory. Forget removes an item from
active use; retained idempotency receipts/export history mean this is not permanent erasure.

## Provider

User-selected model: **GPT-6 Astra via the direct OpenAI Responses API**, `gpt-6-astra`.
The backend posts to `https://api.openai.com/v1/responses`. Set `OPENAI_API_KEY` locally or
configure `PIPGOGO_OPENAI_SECRET_ID` for a JSON Secrets Manager value with `OPENAI_API_KEY`.
Hosted Dev expects `pipgogo/dev/openai` in us-west-2; Prod uses `pipgogo/prod/openai`.
The key stays on the server. Dev IAM and ECS template changes are deployed.
The user populated `pipgogo/dev/openai`; a local backend adapter successfully read it and
validated one live structured GPT-6 Astra conversation response on September 27, 2026.
A separate temporary Fargate task using deployed revision 3 also verified the runtime task
role, secret access and a live structured Astra response, then exited successfully.
Full planning/import/device acceptance remains pending. Bedrock is no longer used; its previously
accepted agreements remain active, but its account runtime calls returned HTTP 403.

Limits: 50-second provider timeout, 6,000 output tokens, 100 KB prompt, 60 AI attempts per account
per UTC day including failures, 20 imports per journey, 5 MB client attachment cap. These are
per-account controls, not an AWS-wide spend ceiling. Add deployment budgets before live rollout.

PDF/JPEG/PNG input is forwarded to the provider; DOCX text uses bounded ZIP/XML parsing. Raw files
are not saved in DynamoDB; proposed/confirmed facts, source filename and timestamps are retained.
Media extraction has mocked coverage only and still needs live model and physical-device checks.
No live weather, opening-hours, places or transport-data provider is connected.

## Deployment and acceptance boundary

The rebuilt backend is deployed to `https://dev.pippipgo.com` from commit `66c505e`,
using ECS task definition `pippipgo-dev-backend:3`. The new app requires `/v1/journeys`.
Old app product endpoints are retired; authentication remains compatible. No data purge occurred.
Public health/readiness returned 200 and unauthenticated journey access returned 401.
A synthetic runtime AI task exited 0 and logged its success marker without credentials or
traveler records. This verifies provider/runtime access, not an authenticated phone journey.
The matching iOS source is published on `develop` as `a237028`; the signed Dev build is ready.
Device installation and acceptance remain pending.

Deployment run: https://github.com/alikian/pippipgo-backend/actions/runs/36346947300
Image digest: `sha256:c881f73fd70106066289e7f2188753df5abdf664fb8ee7b171ee276eb5f4e402`.
Rollback image: `sha256:70420e259fc435ead60004180ccb67452b4acb9b2fdc4eb0e6c3957d372460c7`.
Rollback restores the prior product API and requires its matching older client.

The first acceptance journey is source section 28: four-day San Diego, partly planned; hotel and
itinerary imports; review; travelers/needs/transport; get-to-know or restored memory; light plan;
less-walking feedback; accept/reject proposed changes; account isolation. Include auth regressions,
network failures, exact retries, conflicts, language switching and denied media permissions.

Location/live context, pilot, hands-free hardware and custom wearable remain later milestones.
See [roadmap](../ROADMAP.md) for implementation versus acceptance status.

## Source verification

Backend: 64 tests passed, 1 skipped (DynamoDB pagination under the memory fixture); Ruff lint
and formatting passed. Browser authentication harness: 9 tests passed. iOS: 39 tests across
4 suites passed. Signed Dev build and CloudFormation template validation passed. These automated checks
cover source and mocked behavior; separate runtime evidence appears above. Device acceptance is pending.

## Added requirement — door-to-door journeys

Section 29 of the requirements adds progressive travel-mode/flight intake, upload/manual/search
entry paths, reviewed structured flight segments, outbound and return ground transfers, time-zone
aware first/last-day availability, and flight-change recalculation that protects reservations.
Implemented in source: additive `door_to_door` intake with validated flight segments, four
transfer legs, actual-airport summaries and UTC-based elapsed-time arithmetic. The initial screen
now asks destination, timing and “Anything already decided?”; flight/transfer entry follows later.
Manual flight entry, external search and confirmation uploads are available. Extracted flights
remain proposed until corrected/confirmed; reviewed direction/order replaces the matching segment.
Save recalculates transfer windows and flags accepted activity plans for review. “Save and update
activity suggestions” creates a proposal; reservations and the accepted plan remain unchanged
until deliberate acceptance. Old clients omitting the additive field preserve existing flights.

Live flight status, traffic, pickup instructions and airline-specific buffers are not connected.
Travelers enter transfer estimates and confirm buffers; missing timing remains provisional.
Ambiguous/nonexistent local DST times are rejected for airline clarification. Connecting flights
must follow the previous arrival; cross-airport connections are explicitly flagged.

Verification: 73 backend tests passed, 1 skipped; 41 iOS tests and signed Dev build passed.
A synthetic live GPT-6 confirmation extracted outbound/return EWR flights. Physical-device,
real-media and external search acceptance remain pending.
