# PipPipGo roadmap

**Brand/domain update:** PipPipGo branding and `auth.pippipgo.com` are deployed. Google sign-in, backend access, refresh, revocation and logout passed in Chrome; the signed iPhone build is installed. The user confirmed new-domain iPhone sign-in works on September 26, 2026; repeat device restoration/expiry-refresh/logout checks remain pending.

**Current stage: Dev environment setup · Next: 5.2a — Hosted Dev environment**
Updated September 26, 2026 · [Project time log](TIME_LOG.md)

**Total logged time: 7 hours 0 minutes 33 seconds** · 6 hours estimated + 1 hour 0 minutes 33 seconds recorded; see the time log for scope.

| Available on the iPhone | Still to build |
| --- | --- |
| Google sign-in, traveler profile, companions, trip creation/editing/deletion, pre-trip check-in | Trip packages, photo/camera/PDF/DOCX import, AI planning, durable offline mode |

**Progress:** 6 of 9 Step 2 milestones implemented. AI planning: 0 of 6 Step 3 milestones implemented.
**Latest verification:** 110 Local iOS tests plus 7 configuration checks each for Dev/Prod passed; all three signed builds passed. Previous backend validation: 48 passed, 1 skipped; lint/format passed. Hosted API/device acceptance remains pending.

> Built features still need the device checks listed below. Automated test results are not the same as completed device acceptance. Counts track milestones, not percentage of total effort.

## Status key

| Status | Meaning |
| --- | --- |
| ✅ Complete | The milestone's recorded completion checks passed |
| 🟡 Built · verify | Implemented and automatically tested; device acceptance remains |
| ➜ Next | The next implementation milestone |
| ○ Planned | Not implemented yet |

## Overall roadmap

| Phase | Status | Progress / remaining work |
| --- | --- | --- |
| 1 · Authentication | ✅ Complete | Initial Google/Cognito sign-in, refresh, logout, isolation and revocation verified; repeat affected checks after auth changes |
| 2 · Basic trip flow | 🟡 In progress | 2.1–2.6 implemented; packages, integrated acceptance and photo/camera/PDF/DOCX import remain |
| 3 · AI planning & guidance | ○ Planned | Provider, Plan with AI, refinement, saving, device acceptance and verified arrival guidance |
| 4 · Offline use | ○ Planned | Durable local storage, pending-write queue, synchronization and offline packages |
| 5 · Production readiness | 🟡 Foundation ready | AWS auth/data infrastructure deployed; release versioning (5.1) and backend deployment (5.2), including monitoring, hardening and operational checks, and the public website (5.3) remain |
| 6 · Traveler pilot | ○ Planned | Validate San Diego airport → accommodation, then test with 5–10 travelers |

## 2 · Basic trip flow

| Milestone | Feature | Status | What remains |
| --- | --- | --- | --- |
| 2.1 | Shared authenticated API client | ✅ Complete | Preserve safe retry/version behavior in new features |
| 2.2 | Traveler profile | 🟡 Built · verify | Device save, reopen, edit and clear |
| 2.3 | Companions | 🟡 Built · verify | Device create/edit/delete and account switching |
| 2.4 | Trip list & creation | 🟡 Built · verify | Device create/reopen with selected companions |
| 2.5 | Trip editing & deletion | 🟡 Built · verify | Device edit, conflict review and confirmed deletion |
| 2.6 | Pre-trip check-in | 🟡 Built · verify | Device save/reopen/clear, stale-trip reconfirmation, conflicts and account switching |
| 2.7 | Partial trip package | ○ Planned · next product feature | Generate, list, display and download packages; clearly label missing live guidance |
| 2.8 | Integrated device acceptance with Appium | ○ Planned | Complete 2.8a–2.8c below: setup, regression tests and full journey |
| 2.9 | Trip input from Photos, camera and Files | ○ Planned | Select photos, capture images or import PDF/DOCX files only; extract, review and save trip details |

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

## 3 · AI trip planning & guidance

**Example:** “Create a 10-day trip for Japan. We are OK flying from LAX.”

| Milestone | Feature | Status | Completion check |
| --- | --- | --- | --- |
| 3.1 | AI provider & planning contract | ○ Planned | Backend returns validated structured plans; credentials stay on the server |
| 3.2 | **Plan with AI** screen | ○ Planned | Enter a request, answer clarifications and review a daily itinerary |
| 3.3 | Review & refine | ○ Planned | Edit directly or ask for changes without losing preferences or constraints |
| 3.4 | Save AI-generated trips | ○ Planned | Save one approved trip and reopen its full itinerary; retries do not duplicate it |
| 3.5 | AI planning acceptance | ○ Planned | Complete the Japan/LAX flow on an iPhone with a real provider; check failures and isolation |
| 3.6 | Verified San Diego guidance | ○ Planned | Source and validate arrival guidance separately from itinerary generation |

AI generation is **not currently available in the app**. Manual trip creation is its foundation.
Plans will distinguish suggestions from verified facts and bookings. LAX is a departure preference,
not an existing reservation.

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

## 5.2 · Backend deployment

**Status: ○ Planned.** Deploy a hosted HTTPS API so PipPipGo works without the Mac's LAN
backend. Start with hosted Dev setup (5.2a); build on release versioning (5.1)
for automated delivery before TestFlight distribution and traveler testing.
The next product feature is 2.7, partial companion package.

**App build configuration implemented:** Local (simulator/LAN), Dev (`https://dev.pippipgo.com`) and Prod (`https://pippipgo.com`) schemes select their backend at build time and keep saved tokens separate. Hosted APIs and server-side identity/data isolation remain planned; the current Cognito foundation is shared. The variants replace one another on a device. See iOS `docs/environments.md`.

| Part | Scope | Completion check |
| --- | --- | --- |
| **5.2a — Hosted Dev environment · ➜ Next** | Deploy the API at `https://dev.pippipgo.com` through CloudFormation with TLS/DNS, container registry, runtime IAM and defined data/authentication boundaries. Preserve existing Cognito and retained data. | Dev build on a physical iPhone completes authentication and the trip/check-in flow with the Mac backend stopped; record hosting, readiness, isolation and rollback evidence. |
| 5.2b — Deployment pipeline | Add GitHub Actions tests, Ruff lint/format and container validation. Use short-lived AWS credentials; publish versioned images and deploy by immutable digest from 5.1. Validate in staging before approved production promotion. | A release deploys the tested image; failed checks block promotion, secrets stay outside Git/images, and reruns do not deploy a different artifact under the same version. |
| 5.2c — Hosted API and iOS integration | Configure production Cognito/DynamoDB access and a dedicated HTTPS API URL; update iOS release configuration and restrict development-only settings/callbacks appropriately. Keep the sign-in domain migration separate. | A physical iPhone on cellular or another network completes sign-in, refresh, logout and the implemented trip flow with the Mac backend stopped; record app/backend versions and account-isolation results. |
| 5.2d — Operations and recovery | Add monitoring, actionable alerts, traffic/cost limits and log retention without exposing tokens or travel data. Validate real DynamoDB concurrency, interrupted account deletion, retention/per-trip erasure requirements and backup recovery; document rollback. | Exercise alerts and recovery in staging, roll back to a tested image without losing retained data, and record operational evidence before traveler testing. |

Application hosting is not deployed yet. Record infrastructure deployment and end-to-end
acceptance separately. Backend `docs/deployment.md` will hold the selected service, API URL,
run commands and deployment evidence as this milestone is implemented.

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

## Device checks still open

- [ ] Set up Appium and verify a physical-iPhone automation session (2.8a).
- [ ] Add and run existing-screen Appium regression tests (2.8b).

- [ ] Confirm the Google account chooser on iPhone after the Managed Login upgrade.
- [ ] Profile: save → reopen → edit → clear.
- [ ] Companions: create → edit → delete; verify account switching.
- [ ] Trips: create with companions → reopen → edit → review a conflict → delete.
- [ ] Run the complete trip journey after check-in and packages are built (2.8).

The installed app currently uses the Mac's LAN backend. Drafts and pending requests are held
in memory; durable offline use and a hosted production API are still future work.

## Details and maintenance

The backend and iOS `AGENTS.md` files retain detailed scope, technical constraints, acceptance
criteria and historical evidence. Feature guides are in iOS `docs/traveler-profile.md`,
`docs/companions.md`, and `docs/trips.md`; the AI requirement is in backend
`docs/ai-trip-planning.md`.

Keep `ROADMAP.md` in both repositories synchronized whenever a milestone changes. Move a feature
from **Built · verify** to **Complete** only when its required acceptance evidence is recorded.
