# PipPipGo roadmap — traveler intelligence

Rebaselined September 27, 2026 from the [new product specification](docs/traveler-intelligence-requirements.md).
The prior questionnaire/check-in/package roadmap is superseded and retained in
[history](docs/archive/2026-09-27-legacy-ROADMAP.md). **Pip never overplans.**

| Milestone | Local implementation | Acceptance / remaining scope |
| --- | --- | --- |
| 1 · Trip and traveler intake | New progressive app flow and versioned journeys; party, transportation, lodging, constraints, fixed commitments; import adapter and fact review | Live extraction, device journey, complete saved-traveler management and lifecycle validation |
| 2 · Getting to know you and memory | Conversation, skip/three-exchange completion, atomic scoped learning and natural-language/explicit correction controls | Live learning/correction quality and returning-user acceptance |
| 3 · Personalized initial plan | Typed OpenAI proposal, user acceptance, fixed commitments separate from suggestions | Live quality, geographical/density checks, individual plan-item manipulation |
| 4 · Learning during a trip | Current-trip feedback, temporary context and explicit revision acceptance/rejection | Live adaptive journey, repeated-choice learning and memory corrections |
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

The rebuilt backend is deployed at `https://dev.pippipgo.com` from commit `66c505e`.
New product endpoints begin at `/v1/journeys`; the previous product endpoints are retired.
Authentication remains compatible and legacy data is retained. The matching signed Dev iOS
build is ready but has not been installed during this rebuild. Its source is published on `develop` as `a237028`. See [implementation notes](docs/traveler-intelligence.md).

Provider: **GPT-6 Astra via the direct OpenAI API**, `gpt-6-astra`.
The server secret and direct structured inference were verified using the deployed ECS image
and task role on September 27. Full conversational/planning/import acceptance remains pending. Bedrock was retired after its
runtime returned HTTP 403 despite active agreements; those account agreements were not revoked.

Automated source tests do not establish live AI quality or physical-device acceptance. Complete
the four-day San Diego scenario in requirement section 28 before claiming the rebuilt core accepted.
Production isolation, release delivery, Appium, operations/recovery, public website and durable
offline storage remain separate delivery work. Historical deployment/authentication evidence is retained.
