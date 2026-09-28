# Conversational journey vertical slice

## Source and implementation map

Operative instructions: [user's master implementation prompt](master-implementation-prompt.md).
The live Google source was fetched on September 28, 2026 UTC; modified September 27 at
23:40:33 UTC. Section 27 confirms progressive intake, inferred planning states and reviewed
flight/transfer details. The master prompt's latest screen direction takes precedence.

| Capability | Existing implementation reused | Work in this slice |
| --- | --- | --- |
| Authentication and ownership | iOS AuthenticationStore, Cognito/Keychain, shared APIClient; backend auth.py and user-partition repository | Preserved; no identity, IAM, domain or storage migration |
| Native entry and conversation | RootView → PipHomeView → TripIntakeView/PipTripView | Resume saved next step, immediate Nothing yet, skip, review and plan handoff |
| Trip and retry persistence | TravelerIntelligence.swift, intelligence_models.py, versioned intelligence.py mutations | Additive conversation progress and immutable skip actions |
| Imports and travel | ImportView/ImportReviewView, OpenAI extraction, journey_travel.py | Planning blocked until proposed imports are reviewed; existing four transfer legs retained |
| AI orchestration | OpenAIIntelligence using configured server-side model/secret | Separate character, intake policy and planning rules; grounded answer extraction; deterministic routing |
| Plans and feedback | Existing proposal/accept/reject flow | Explicit change summary; timed-window validation; empty clarification preserves the plan |
| Memory and localization | Existing scoped memory and English/Farsi string catalog | Inferred persistent observations require review; next-step copy localized |
| Delivery | Existing develop → GitHub checks → ECR/ECS pipeline | No new infrastructure or external provider |

## Flow and storage

The journey now includes a `conversation` object: bounded topic answers with source evidence,
skipped topics, turn count, next_step and current question. Answers survive reload and the
12-message model context window. Only exact evidence from the current message can establish
additional answered topics. Mode/status classification can fill unknown fields; it cannot
replace reviewed flights. Confirmed imports and saved lodging prevent duplicate questions.

Application priorities: review proposed imports; obtain destination/timing; known bookings;
travel mode; relevant flights; lodging; relevant transfers; offer a plan. Optional intake is
bounded to four exchanges and can be skipped sooner. A provisional plan can start before all
optional details are known. Inferred planning state remains internal. Missing live data stays
unknown; this policy does not turn a skipped transfer into an arranged ride.

`skip_intake` persists a deliberate skip using the existing expected-version/idempotency
contract. Proposed imports block plan/feedback/accept actions until review, including clients
that bypass the UI. Known business rejections release the client's pending action without
silently overwriting a version conflict.

Intake replies contain an acknowledgement plus the application's next question. Models cannot
insert another question into that reply. Confirmed facts remain separate from inferred memory.
New inferred persistent memories are review suggestions, not automatic writes. Explicit general
preferences can still be saved; temporary fatigue remains temporary. Only actual onboarding
conversation exchanges count toward its three-exchange limit.

Timed plan suggestions have optional offset-aware starts_at/ends_at. If supplied, application
code rejects overlap with derived arrival/departure windows. Unknown timing remains provisional.
Legacy prose-only timing cannot be independently verified by this validator. Revisions compare
stable suggestion IDs and expose unchanged/added/changed/removed items. Fixed bookings remain
outside replaceable suggestions. Empty feedback output means clarification/no change, not a
proposal to delete every activity.

## Acceptance boundaries

Automated checks cover saved progress, skipped topics, grounded extraction, import gating,
current-user ownership, exact retries, memory confirmation, time-window rejection and plan
preservation. Synthetic live-provider checks use an in-memory repository with no personal
traveler data. Screenshots use an isolated preview bundle with a synthetic name/destination;
they establish layout only, not authenticated device acceptance.

Still pending: physical-iPhone upload/review → transfer → plan → feedback acceptance, denied
speech permissions, VoiceOver and large dynamic text interaction, live route/traffic/flight
sources, camera capture/live voice, richer onward/train segments, and real provider costs or
pickup rules. Existing external flight search and manual estimates are the fallback. No booking
or cancellation capability was added. Production/offline/hardware work is outside this slice.

Next smallest experiment: one traveler runs the San Diego → EWR hotel-arrival flow on Dev,
corrects one imported fact, accepts a light evening plan, requests less walking and reopens it.
Record duplicate questions, unclear estimates and unnecessary choices before broadening scope.
