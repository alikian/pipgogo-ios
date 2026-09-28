# PipPipGo roadmap — traveler intelligence

Rebaselined September 27, 2026 from the [new product specification](docs/traveler-intelligence-requirements.md).
The prior questionnaire/check-in/package roadmap is superseded and retained in
[history](docs/archive/2026-09-27-legacy-ROADMAP.md). **Pip never overplans.**

| Milestone | Local implementation | Acceptance / remaining scope |
| --- | --- | --- |
| 1 · Trip and traveler intake | Personal one-question intake with saved progress, skips, plan handoff and import-review gating; compact summary, speech/upload and inferred readiness; reviewed outbound/connection/return flights, external search, four transfer legs, party/lodging/commitments and import review | Door-to-door device acceptance (section 29), real booking/media review, saved-traveler management and lifecycle validation |
| 2 · Getting to know you and memory | Conversation, skip/three-exchange completion, atomic scoped learning and natural-language/explicit correction controls | Live learning/correction quality and returning-user acceptance |
| 3 · Personalized initial plan | Typed OpenAI proposals with revision diffs and timestamp-window validation; airport/time-zone-aware transfer and first/last-day windows; fixed commitments protected | Device/live-quality acceptance of airport-specific timing, geographical/density checks, individual plan-item manipulation |
| 4 · Learning during a trip | Current-trip feedback, temporary context and explicit revision acceptance/rejection | Flight-change device acceptance, live adaptive journey, repeated-choice learning and memory corrections |
| 5 · Multilingual and multimodal | English/Farsi catalog and RTL, text/photo/PDF/DOCX import path | Translation/device review, camera/audio/live voice and media acceptance |
| 6 · Location and live context | Planned | Permission-driven location, authoritative places/hours/transit/weather |
| 7 · Real-world pilot | Planned | 5–10 travelers; usefulness, trust, cognitive burden and repeat-use intent |
| 8 · Hands-free existing hardware | Planned after pilot | Bluetooth, microphone/wind, battery, comfort and conversation |
| 9 · Purpose-built wearable | Conditional on demand | Hardware design, regulatory requirements and manufacturing case |

## Retained foundation

Google/Cognito authentication, stable subject ownership, Keychain, refresh/revocation, account
loading/export/deletion, DynamoDB transactions and deployed ECS infrastructure remain. Legacy
product records are retained. The old product screens and APIs have been replaced in local source.

## Delivery boundary

The rebuilt backend is deployed at `https://dev.pippipgo.com` from commit `7b4d7bb`.
New product endpoints begin at `/v1/journeys`; the previous product endpoints are retired.
Authentication remains compatible and legacy data is retained. The matching signed Dev iOS
build is ready but has not been installed during this rebuild. Its source is published on `develop` as `d20cb8e`. See [implementation notes](docs/traveler-intelligence.md).

Provider: **GPT-6 Astra via the direct OpenAI API**, `gpt-6-astra`.
The server secret and direct structured inference were verified using the deployed ECS image
and task role on September 27. Full conversational/planning/import acceptance remains pending. Bedrock was retired after its
runtime returned HTTP 403 despite active agreements; those account agreements were not revoked.

Automated source tests do not establish live AI quality or physical-device acceptance. Complete
the four-day San Diego scenario in requirement section 28 before claiming the rebuilt core accepted.
Production isolation, release delivery, Appium, operations/recovery, public website and durable
offline storage remain separate delivery work. Historical deployment/authentication evidence is retained.

## Added scope — door-to-door journeys

[Requirement section 29](docs/traveler-intelligence-requirements.md#29-door-to-door-journey-outbound-and-return)
is implemented and deployed to Dev; device acceptance remains separate. Keep initial intake to destination, when,
and “Anything already decided?” Then progressively collect transport mode, booking status,
reviewed outbound/connection/return flights and arranged or proposed ground transfers.
Plan from home to hotel and back using actual airports, local times/time zones, baggage,
airport buffers, hotel timing and rest. Unknown details remain provisional. Flight changes
produce reviewable updates while preserving confirmed reservations. Extend acceptance with
San Diego → New York cases for JFK, LGA and EWR, plus return and connecting/overnight flights.

Door-to-door verification: 75 backend tests passed (1 skipped), 42 iOS tests passed, signed Dev
build passed. Live synthetic GPT-6 extraction returned separate outbound/return segments.
Unknown details remain provisional; route times are user estimates, with no live flight/traffic
feed. Cross-airport connections are flagged for explicit transfer planning. Real-device visual,
real-confirmation media, flight search handoff and complete journey acceptance remain pending.

Conversational intake (section 30): implemented with explicit/confirmed preferred-name memory,
editable trip summary, ambiguous-date confirmation, speech/type/upload input, quiet Nothing yet,
and context-aware acknowledgement/next question. No planning-state questionnaire remains.
The synthetic simulator layout was visually checked; device speech/permission and full-flow acceptance remain pending. Existing travelers/reservations
can still be edited separately from the light intake screen.

Latest vertical slice: [implementation map and acceptance boundaries](docs/conversation-slice.md).
