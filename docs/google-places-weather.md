# Google Places and weather

Requested September 29, 2026 for typed Ask Pip and Talk to Pip. The existing Google
Cloud project is `pipgogo` (console display name `PipGoGo`, project number
`367277379611`); existing OAuth configuration is preserved.

## Runtime

The backend exposes `search_places` and `current_weather` function tools to
GPT-6 Luna. Live audio keeps `gpt-live-1` and delegates these calls to Luna.
The server executes functions; provider keys are never sent to OpenAI or iOS.
Typed requests allow two lookups; each five-minute voice session allows eight.
Calls have eight-second HTTP timeouts and bounded response sizes. Live execution
runs separately from audio forwarding. Duplicate call IDs reuse their result
within that request/session, and account-disable checks fence voice tool execution.

Places uses Text Search (New), five results and an explicit field mask: place IDs,
names, addresses, Google Maps URLs, business status and third-party attributions.
Nearby searches use the supplied device coordinates, with a 5 km location bias
and distance ranking. This is not a strict radius or exhaustive nearest result.
An explicitly named area can be searched without device location. Missing/stale
locations never fall back to the AWS task's public IP or the profile hometown.
Opening hours, availability, ratings and prices are not fetched. The separate
road-distance tool described below adds driving distance and estimated time.

Weather uses Google's current-conditions endpoint at the recent device location,
with metric values and their units, observation time, temperature, feels-like,
humidity, UV, precipitation and wind. Current conditions are not forecasts or
severe-weather alerts. Destination weather is not implemented. Both providers
return explicit unavailable states on failures; no synthetic fallback is used.

Only short place queries/areas or coordinates are sent to Google. OpenAI sharing
boundaries remain unchanged: typed chat excludes saved trips/companions; voice
uses its authorized read-only snapshot. The existing admin capture includes
available tool context and conversation replies. No standalone Places cache or
venue database is added. Provider attribution and Google Maps links are requested
in replies. Google usage is billed separately and is not included in the existing
OpenAI-only admin USD estimate.

## Credentials and deployment

- CloudFormation `infra/delivery.yaml` owns retained secret
  `pippipgo/dev/google-places` and backend task-role `GetSecretValue` permission
  scoped to its exact ARN. The value is managed separately from the template.
- Secret JSON key: `GOOGLE_PLACES_API_KEY`. Local override:
  `PIPGOGO_GOOGLE_PLACES_API_KEY`. Runtime setting:
  `PIPGOGO_GOOGLE_PLACES_SECRET_ID`.
- Google key name: `PipPipGo Dev Backend Places`, ID
  `1927ff33-ef5d-4c30-9a66-e7b9672a4ae5`.
- API scope is restricted to Places API (New), Weather API and Routes API.
  ECS currently assigns changing public task IPs. No fixed IP restriction is
  claimed; that requires separately managed stable egress. No browser/iOS
  application restriction is suitable for this backend key.

## Evidence and remaining acceptance

Places API (New) was enabled in Chrome after explicit terms/key approval.
After the subsequent approval, Weather API was enabled and the two-API key
restriction (Places New and Weather) was saved and read back. CloudFormation delivery
update completed, provisioning the retained secret container and scoped IAM.
The user completed the credential transfer; AWS reports an AWSCURRENT version.
The temporary loopback transfer server was stopped afterward. Live Google checks
returned five nearby places and current conditions using public downtown San Diego
test coordinates. GPT-6 Luna called both real tools and produced a valid attributed
typed reply. ECS revision 30 is stable on Dev, deploying commit `710cb4d` through
[run 36662687809](https://github.com/alikian/pippipgo-backend/actions/runs/36662687809).
The workflow succeeded and CloudFormation reached UPDATE_COMPLETE.
HTTPS health/readiness returned 200 and unauthenticated `/v1/me` returned 401.
GPT-Live accepted both tool definitions
with Luna delegation. A live local-backend relay test then sent generated speech,
executed both real Google tools through Luna, and received 566 audio chunks plus
a spoken transcript attributing the place and current-weather results. This proves
the provider/tool/audio path with synthetic speech, not physical-device acceptance.
The signed Dev iOS build, strict signature verification and three focused
conversation-context simulator tests passed. The user approved installation and
the signed Dev update was installed on Akiphone (com.pipgogo.ios). Physical-device
Places/weather acceptance has not yet been observed.

227 backend tests passed, one skipped; Ruff lint/format and CloudFormation lint
passed. Tests include missing/stale location, minimal requests, no secret leakage,
provider failures, quotas, deduplication, typed function continuation, and actual
mocked voice relay tool output/resumption. These are not live-provider or phone
acceptance. Verify actual Places/Weather replies and spoken results after setup.

## Protocol references

- [Google Text Search (New)](https://developers.google.com/maps/documentation/places/web-service/text-search)
- [Google current weather](https://developers.google.com/maps/documentation/weather/current-conditions)
- [Google Places attribution](https://developers.google.com/maps/documentation/places/web-service/policies)
- [OpenAI Live delegation](https://developers.openai.com/api/docs/guides/live-delegation)

## Voice location regression — September 29

After the voice-page layout cleanup, the user reported a gas-station question
receiving an incorrect missing-location reply. Inspection of the retained session
at 03:17:08 UTC confirmed a recent location was present with status available,
but no Places tool was called. The removed visual card was not the location
acquisition path; acquisition remains in the voice store and root foreground state.

The backend now adds an explicit location-availability instruction only when
validated current context has a fresh fix, and the shared prompt requires a Places
lookup for nearby distance questions. Old conversation statements cannot override
current session location. Road distance remains unavailable and is stated separately.
Missing/stale location behavior is preserved.

229 tests passed (one skipped), including fresh/stale/missing voice-context cases.
A live relay test of “How far is the nearest gas station?” used public test
coordinates, called the real Google Places tool and returned 541 audio chunks with
an attributed nearby result and an explicit route-distance limitation. No false
missing-location reply occurred in that check. Physical-device retry remains pending.

Fix deployed as `9d42a88`, ECS revision 31, through successful [run 36664046537](https://github.com/alikian/pippipgo-backend/actions/runs/36664046537). CloudFormation completed; HTTPS health/readiness returned 200 and unauthenticated account access returned 401. Start a new voice session to pick up updated instructions.

## Road-distance extension

`nearby_road_distances` combines a location-biased Text Search of up to five places
with one Google Routes Compute Route Matrix request (one origin, at most five
destinations). Gas-station queries use strict `gas_station` filtering. The origin
comes only from validated recent device context; destination IDs come only from
Google Places results, not model arguments. Both typed and live voice use the same
tool and existing per-request/session limits.

The tool returns distance along Google's recommended driving route in meters/miles
and traffic-aware estimated minutes, sorted by road distance among valid results.
It does not promise the absolute closest business, shortest possible road route,
walking/transit distance, opening hours or fuel availability. Missing/error routes
are omitted and counted, never interpreted as zero. Provider failures do not
produce fabricated or straight-line fallbacks. Requests remain bounded with field
masks, eight-second HTTP timeouts, and private header credentials from the existing
AWS secret. No new credential is created.

244 backend tests passed (one skipped); Ruff lint/format passed. The updated iOS
disclosure signed Dev build and strict signature verification passed; installed
on Akiphone through the approved Dev-update workflow.
Google Routes API was enabled in Chrome after user approval. The existing key
restriction was saved and read back with exactly Places New, Weather and Routes.
Live Routes validation returned five routes; typed GPT-6 Luna called the new tool
and replied with about 0.6 miles and three minutes driving to the closest checked
gas station from public downtown San Diego test coordinates. The live voice relay
then executed the real Routes tool and spoke the same approximate mileage and
driving time (524 output audio chunks). Deployed `3bc09e6` as ECS revision 33
through successful [run 36666007388](https://github.com/alikian/pippipgo-backend/actions/runs/36666007388).
CloudFormation reached UPDATE_COMPLETE; HTTPS health/readiness returned 200 and
unauthenticated account access returned 401. Phone acceptance of the new
road-distance reply remains pending; start a new voice session.

Reference: [Google Compute Route Matrix](https://developers.google.com/maps/documentation/routes/compute_route_matrix).
