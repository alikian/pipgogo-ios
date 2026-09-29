# PipPipGo — simple travel organizer

Current scope selected September 28, 2026. This supersedes the traveler-intelligence product roadmap.

## Product

- My Profile: name, optional age and home town; optional interests and important notes.
- Companions: reusable people with name, optional age, home town, interests and important notes. Dietary/accessibility information is only entered explicitly.
- Trips: name, who is traveling (me and selected companions), ordered destinations and optional notes. Trips can be saved before destinations or bookings are known.
- Destinations: city/place, optional arrival/departure dates, hotel name/address and check-in/check-out dates.
- Travel: plane, train or car, plus optional flight/train number, timing or driving notes. Travel belongs to the destination being reached; the preceding destination is the origin. First-stop transport is optional. Review travel details after reordering stops.
- Add, edit and delete trips and companions; remove companions from trips before deleting them. Destinations can be added, removed and reordered.

No conversation, personality onboarding, generated plan, memory review or import is required for this core flow. AI credentials, server secret configuration and the selected GPT-6 Astra model are retained for future use. No credentials move into the app.

## Implementation

The signed-in home opens the organizer. GET/PUT `/v1/travel-organizer` read and save a single account-owned aggregate containing profile, companions and trips. An empty account reads version 0. Writes require an idempotency key and expected version. Existing repository transactions, sync/export and account-deletion fencing apply. The aggregate has a 250 KB storage limit, at most 30 companions, 50 trips and 30 destinations per trip.

A save retains its exact body/key/version on an uncertain result. A version conflict requires explicit review and loading the latest saved data; the app never silently overwrites it. Session resets clear drafts/pending operations and late responses are fenced.

Existing legacy and traveler-intelligence records are retained in their existing record kinds. They are not automatically converted into organizer trips. Existing AI endpoints remain available but are not used by the new home screen. CloudFormation, Cognito, ECS and DynamoDB configuration is unchanged.

## Acceptance

Create a profile and companion. Create an Italy trip with both travelers, Rome and Florence, hotel stays and a train between them. Save/reopen, edit, reorder and delete stops. Exercise plane/car choices and missing booking details. Verify companion deletion protection, date validation, retry identity, concurrent edits, two-account isolation and sign-out reset.

The new API must be deployed before installing the matching app against Dev. Source/build tests are separate from deployed API and physical-device acceptance. Translation and physical-device visual review remain pending.

## Verification — September 28, 2026

99 backend tests passed, 1 skipped; Ruff lint and formatting passed. 48 iOS simulator tests passed, including organizer timeout/retry and conflict review. Final signed Dev build passed. Dev deployment is complete; physical-device acceptance and translated new-screen copy remain pending. Existing AI credentials/configuration were preserved; no new live inference was needed or performed.

## Dev rollout — September 28, 2026

Backend commit `e1e3d2a6fc4ab9d81d1e73e0d2a2adf5c757af86` deployed successfully through [GitHub Actions run 36391002936](https://github.com/alikian/pippipgo-backend/actions/runs/36391002936). CloudFormation `pippipgo-dev-backend` is UPDATE_COMPLETE and ECS `pippipgo-dev-backend:9` is stable with one desired/running task.

Image digest: `sha256:ab3c39af12af95bc47ea91904d87ebcb7ccfef629387a5e3efd907d84f2263eb`. Previous rollback image: `sha256:6d6bebef32f4617226869b41b098deff36ef3710d0e80655447d70ebb522e4b9`.

Live HTTPS health/readiness returned 200; organizer GET and PUT without authentication returned 401. Production OpenAPI is disabled. Authenticated organizer CRUD on a physical phone remains pending. The deployed task retains `pipgogo/dev/openai` and `gpt-6-astra`; no secret value was changed or printed and no new inference test was performed. iOS installation is not part of this backend rollout.

## Destination editor crash fix — September 28, 2026

The affected simulator was paused after `Fatal error: Index out of range`. A sampled main-thread stack identified an array-backed destination date binding during navigation/keyboard teardown. The trip editor reinitialized its draft on appearance, removing unsaved stops as the destination screen navigated back. Draft state is now initialized once per editor, and destination bindings resolve stable IDs with safe reads/no-op writes after removal. Explicit conflict reload remains available.

49 simulator tests passed, including destination-binding reorder/removal regression coverage. Signed Dev and Dev simulator builds passed. The fixed Dev app was installed and launched on the affected iPhone 16 simulator without deleting its data. Full interactive return/date-entry and physical-device acceptance remain pending. No backend redeployment is required.

Destination controls: removed Edit mode; each destination supports swipe-to-delete. Add destination creates a draft stop and immediately opens its form. Long-press a destination for Move earlier/later. Signed Dev and simulator builds passed; updated Dev app installed/launched on the iPhone 16 simulator.

Updated deletion interaction: the visible × is removed. Swipe left on a destination to reveal Delete, or swipe fully to delete. Signed Dev and simulator builds passed; simulator app updated.

## Google profile photo

The home profile row loads the signed-in Google picture through the configured Cognito `/oauth2/userInfo` endpoint. It displays a circular photo, or a person icon when absent/unavailable. Only HTTPS Googleusercontent URLs are accepted; bearer credentials are sent to Cognito, never to the image host. Photo loading does not block app access. Sign-out/account changes clear the photo and fence late profile responses.

CloudFormation `pipgogo-dev-foundation` updated in place: Google `picture` mapping and app-client read/write access to `picture`. Stack UPDATE_COMPLETE and live mapping/permissions verified. Existing Google accounts must sign in again to populate the new attribute. No AI credential changes. [Cognito mapping reference](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-specifying-attribute-mapping.html).

50 iOS tests, signed Dev/simulator builds, 99 backend tests (1 skipped), Ruff and CloudFormation lint passed. Simulator app installed/launched. Actual account-photo rendering after renewed Google sign-in remains user/device acceptance.

Home header compacted: PipPipGo and Sign out share one navigation row. Signed Dev/simulator builds passed; simulator app updated. User confirmed Google photo is working.

Companion organization: the home profile box shows up to three companion names plus a remaining count in one compact secondary line. Companion management is inside My Profile; the separate home section is removed. Trips offer Add someone, saving the new companion and selecting them without resetting the trip draft. Existing Save/retry/conflict behavior is retained. 50 simulator tests and signed Dev/simulator builds passed; simulator app installed/launched. Interactive acceptance remains pending.

## Ask Pip — optional travel chat

Home now offers Ask Pip with an initial greeting and three suggested questions: a three-day New York trip next weekend, the nearest luggage locker, and a nearby Mediterranean restaurant. Suggestions fill the composer for review. Pip can ask relevant follow-ups and revise plans already discussed in chat, preserving unaffected details. Replies can prepare a new trip draft; saving requires review in the trip editor.

The user authorized **chat messages, chat history and the traveler profile** for OpenAI sharing. The server includes only profile name, age, home town, interests and important notes. Saved companions and trips are excluded. Home town is never treated as current location. The UI explains this boundary. The editable system instructions live in backend root `prompt.md`, copied into the container; prompt-only changes trigger CI deployment. GPT-6 Astra and existing server-side Secrets Manager credentials are unchanged. No AI credentials are in the iOS bundle.

GET/PUT `/v1/travel-chat` uses a separate per-account record with expected versions and idempotent receipts. It retains the latest 40 messages and sends recent history within a 60 KB text budget. Existing atomic daily limits (60 attempts/account) apply. Uncertain requests retain the exact body/key/version; conflicts require loading the latest chat before resubmitting. Account reset clears chat/composer/pending state and late responses are ignored. Account export/deletion covers the chat record.

No live GPS, place search, availability or opening-hours service is connected. Pip asks for an area when nearby requests lack location, confirms ambiguous dates, and redirects unrelated questions.

Verification: 105 backend tests passed (1 skipped), 51 iOS tests passed, Ruff and signed Dev/simulator builds passed. Synthetic live GPT-6 tests generated a New York plan, revised only day two while retaining days one and three, and redirected unrelated coding. These tests used no saved user data and are distinct from authenticated phone acceptance.

Ask Pip Dev rollout: final backend `2d4ebd4b068b294420e53c543b08568e0f01e085`, [successful run 36397771743](https://github.com/alikian/pippipgo-backend/actions/runs/36397771743), stable ECS revision 11. Image `sha256:27fd2c7c917f5a76174db3fe11d1f5ba27b74e3ceb03fd71ae4b69f6392b7837`. HTTPS readiness returned 200 and unauthenticated chat read/write returned 401. AI model/secret reference unchanged. Updated Dev app installed/launched on the iPhone 16 simulator. Actual authenticated user conversation/profile personalization remains user acceptance; live model checks used synthetic chat only.

Chat formatting: assistant replies render inline Markdown emphasis/web links plus headings, numbered/bulleted lists, quotes and code blocks using native SwiftUI text. User messages remain literal. Existing saved replies gain formatting on display. 52 simulator tests and signed Dev/simulator builds passed; simulator app updated. Budget support was added in the subsequent update below.

## Optional trip budget and costs

Trips offer Budget & costs with a total budget, one currency (USD, CAD, EUR, GBP, AUD or JPY), and estimated/actual amounts for flights, hotels/stays, transport, food, activities and other costs. Summary totals show estimated costs, spending, unallocated budget and remaining budget, with over-budget amounts highlighted. Blank means unknown; estimates and actuals are counted separately. Changing currency does not convert amounts. Save the trip to persist budget edits.

Amounts use exact decimal strings in the API and Decimal arithmetic on iOS. Negative/invalid amounts and fractional yen are rejected. Existing trips need no migration, and older clients that omit budget fields preserve previously saved budgets. Chat drafts can prefill explicitly discussed budget/cost amounts; review is required before saving.

Verification: 109 backend tests passed (1 skipped), Ruff lint/format passed, 53 simulator tests passed, and signed Dev/simulator builds passed. Physical-device acceptance remains pending.

Budget Dev rollout: backend `e366558a76536cc4d1f0d8c8c9fc9b86f05f4118`, [successful run 36400462253](https://github.com/alikian/pippipgo-backend/actions/runs/36400462253), ECS revision 12. Matching Dev app installed/launched on the iPhone 16 simulator with existing data preserved.

## Reviewed trip creation from Ask Pip

Ask Pip can now prepare a new trip draft when asked to save the discussed plan. Existing conversations have Create trip from this chat; draft replies show Review trip. The editor prefills the name, ordered destinations/dates, travel details, notes and budget. Explicit adult/child party counts are preserved separately from named companion selection. Names are optional; select or add saved companions during review without increasing the total. Specific ages remain in notes. Cancel makes no trip change; Save persists through the existing versioned organizer endpoint. Existing saved trips are never sent to the provider or automatically overwritten.

Server-generated draft and stop IDs cannot target existing records. Draft IDs survive message replay/readback, and saved drafts show Trip saved. Immutable organizer retries retain the same body/key/version. Old messages without drafts remain readable. Older apps ignore the optional draft field. The server bounds serialized chat history/drafts below the database item limit.

Verification: 111 backend tests passed (1 skipped), Ruff passed, signed Dev and simulator builds passed. A synthetic live GPT-6 Astra draft preserved two destinations, exact dates and a GBP 2000 budget; no real user records were used. Phone acceptance remains pending.

Chat-draft rollout: backend `a999d34`, [successful run 36401831517](https://github.com/alikian/pippipgo-backend/actions/runs/36401831517), ECS revision 13. 54 iOS tests passed; matching Dev app installed/launched on the iPhone 16 simulator.

## Complete party size in trip drafts

An optional party object stores total adults and children, including the user. Who is traveling displays the total and editable counts independently of named companion assignments; unnamed travelers are still part of the trip. The total must be 1–30 and at least the number of selected named travelers. Older clients that omit party preserve existing values. The chat prompt preserves explicit party counts and never adds the user twice. Older drafts with the explicit note pattern “Travelers: 3 adults and one 14-year-old” recover those counts locally when opened, without changing remote data until Save.

113 backend tests (1 skipped), 55 simulator tests, Ruff, signed Dev/simulator builds passed. A synthetic live GPT-6 Astra check preserved 3 adults and 1 child, including the user. Real-device acceptance remains pending.

Party fix rollout: backend `58fd168`, [successful run 36402973166](https://github.com/alikian/pippipgo-backend/actions/runs/36402973166), stable ECS revision 14. Updated Dev app installed/launched on the iPhone 16 simulator, preserving data.
