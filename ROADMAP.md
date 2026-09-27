# PipPipGo roadmap

**Brand/domain update:** PipPipGo branding and `auth.pippipgo.com` are deployed. Google sign-in, backend access, refresh, revocation and logout passed in Chrome; the signed iPhone build is installed. The user confirmed new-domain iPhone sign-in works on September 26, 2026; repeat device restoration/expiry-refresh/logout checks remain pending.

**Current stage: Dev hosted on ECS Fargate · Next: 5.2a — Device acceptance**
Updated September 27, 2026 · [Project time log](TIME_LOG.md)

**Total logged time: 7 hours 29 minutes 28 seconds** · 6 hours estimated + 1 hour 29 minutes 28 seconds recorded; see the time log for scope.

| Available on the iPhone | Still to build |
| --- | --- |
| Google sign-in, traveler profile, companions, trip creation/editing/deletion, pre-trip check-in | Trip packages, photo/camera/PDF/DOCX import, AI planning, durable offline mode |

**Progress:** 6 of 9 Step 2 milestones implemented. AI planning: 0 of 6 Step 3 milestones implemented.
**Latest verification:** 110 Local iOS tests plus 7 configuration checks each for Dev/Prod passed; all three signed builds passed. Backend: 56 passed, 1 skipped; lint/format passed. Dev GitHub deployment and HTTPS smoke checks passed; physical-device acceptance remains pending.

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
| 5 · Production readiness | 🟡 Dev deployed | Standard ECS Fargate and GitHub Dev deployment delivered; device acceptance, semantic releases, Prod, operations and website remain |
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
the next work milestone is **5.2a — hosted Dev device acceptance**; the next product feature remains **2.7 — partial companion package**.

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
semantic release versioning for production deployment and TestFlight distribution.
Commit-based Dev deployment is already implemented. Backend and iOS versions
remain independent; the next product feature is 2.7, partial companion package.

| Part | Scope | Completion check |
| --- | --- | --- |
| 5.1a — Version policy | Define independent major.minor.patch release versions, including pre-1.0 breaking-change rules, and a single version source per repository. Classify release changes with `fix:`, `feat:` and explicit breaking-change markers. Keep release versions distinct from API `/v1` and record versions. | Document examples for fixes, features and breaking changes; version sources agree with packaged application metadata. |
| 5.1b — Release PR automation | Use GitHub Actions to prepare version bumps and changelogs in release PRs. Require passing checks and deliberate approval before merging; create immutable Git tags and GitHub releases from the approved commit. | Demonstrate a release PR and tag with matching version/commit; repeated workflow runs cannot duplicate a release or move an existing tag. |
| 5.1c — Build identity and delivery · partially implemented | Assign monotonically increasing iOS build numbers; stamp app version/build and source commit into artifacts. Identify backend images by version, commit and immutable digest. Connect approved releases to deployment/TestFlight workflows when available. | Concurrent runs and retries cannot reuse a build number for different uploads; artifacts and test reports identify the exact backend and iOS versions/commits tested together. |
| 5.1d — Compatibility and recovery | Preserve compatibility with older installed apps; document backend rollback to a previously tested image and iOS recovery through a new build/release. | Rehearse a release and backend rollback in staging; record compatibility results and retain the release artifacts needed for recovery. |

Semantic versioning and release PR automation are not implemented yet. Backend Dev
images already have immutable commit tags, source revision labels and deployment digests.
iOS build-number automation, release versions and TestFlight delivery remain planned.

## 5.2 · Backend deployment

**Status: 🟡 Dev deployed; device acceptance pending.** Standard ECS Fargate serves
`https://dev.pippipgo.com`. GitHub Actions deploys `develop` to Dev; `main` is reserved
for Prod and blocked until separate persistence and apex DNS are ready. Semantic
release versioning (5.1), production delivery and operations acceptance remain.
The next product feature is 2.7, partial companion package.

**App build configuration implemented:** Local (simulator/LAN), Dev (`https://dev.pippipgo.com`) and Prod (`https://pippipgo.com`) schemes select their backend at build time and keep saved tokens separate. Dev is deployed and intentionally shares existing development Cognito/data with Local; Prod identity/data isolation remains a prerequisite. The variants replace one another on a device. See iOS `docs/environments.md`.

| Part | Delivered | Remaining acceptance/work |
| --- | --- | --- |
| **5.2a — Hosted Dev · 🟡 deployed** | Standard ECS Fargate at `https://dev.pippipgo.com`; separate CloudFormation, HTTPS/DNS, ECR, scoped runtime IAM; live authenticated access and two-account isolation passed | Verify the Dev app on a physical iPhone over cellular with the Mac backend stopped; complete the planned rollback evidence |
| 5.2b — Deployment pipeline · 🟡 Dev implemented | GitHub Actions tests, Ruff, CloudFormation lint and real container checks; branch-bound OIDC; immutable image digests; successful initial deployment and rolling update | Semantic release/version automation from 5.1 and reviewed production promotion; configure production prerequisites before enabling its workflow |
| 5.2c — Production API and iOS integration · ○ planned | Local/Dev/Prod app schemes and environment indicator implemented; Dev installed on Ali’s iPhone 12 | Separate Prod Cognito/DynamoDB, coordinate apex DNS, configure matching Prod app authentication, deploy and verify the complete physical-device journey |
| 5.2d — Operations and recovery · 🟡 initial controls only | CPU scaling with a maximum task count, 14-day logs, unhealthy-target/5xx alarms, circuit-breaker rollback and documented digest redeployment | Alert subscriptions/drills, traffic and budget controls, intentional rollback drill, real concurrency/deletion recovery, retention and backup recovery checks |

Dev hosting and delivery stacks are deployed. Backend `infra/hosting.md` documents
standard Fargate, persistence separation, branch strategy, cost assumptions and rollback.
Deployment success remains separate from physical-device and production acceptance.

### 5.2a — Dev deployed; acceptance remains

**Status: 🟡 Deployed September 27, 2026; physical-device acceptance pending.**
The Dev build is installed on Ali’s iPhone 12. GitHub Actions deployment, immutable
ECR image, TLS, readiness, authenticated access, two-account isolation and browser
refresh/revocation/logout checks passed. See backend `docs/hosting-verification.md`. Complete the
remaining acceptance checks below before marking this milestone complete.

- [x] Select standard ECS Fargate in `us-west-2`; document cost assumptions and the shared Local/Dev data/authentication boundary.
- [x] Keep `persistence.yaml` separate from `delivery.yaml` and `hosting.yaml`; preserve the deployed persistence stack and authentication resources.
- [x] Deploy HTTPS, DNS, registry, runtime IAM, logs, scaling and initial alarms through CloudFormation.
- [x] Verify health/readiness, authenticated account access, trip creation, two-account isolation, cleanup and browser refresh/revocation/logout.
- [x] Complete a GitHub-driven rolling update: [run 36302546875](https://github.com/alikian/pippipgo-backend/actions/runs/36302546875), task definition revision 2, 56 backend tests passed and 1 skipped.
- [ ] Confirm **Build: Dev**, sign-in, refresh/logout and the implemented trip/check-in flow on a physical iPhone using cellular or another network with the Mac backend stopped.
- [ ] Rehearse an intentional rollback to a known-good image and record the result; a successful rolling update does not prove rollback.

Browser testing used a temporary process-only DNS pin while the Mac cached an earlier
negative result; hostname/TLS verification remained enabled. GitHub's public HTTPS
checks used normal DNS. See the [verification evidence](https://github.com/alikian/pippipgo-backend/blob/develop/docs/hosting-verification.md)
for the exact boundaries. Device acceptance remains unconfirmed.

### Branch strategy and environment boundaries

| Branch/build | Target | Current state |
| --- | --- | --- |
| Local app | Mac localhost/LAN backend | Available when the local server is running; server currently stopped |
| `develop` / Dev app | `https://dev.pippipgo.com` | Default branch in both repositories; backend pushes deploy through GitHub Actions; documentation-only pushes skip deployment |
| `main` / Prod app | `https://pippipgo.com` | Reserved for production promotion; deployment disabled until separate persistence/authentication and apex DNS ownership are ready |

Local and Dev deliberately share development accounts and trip data. Production must
use separate resources. App variants replace one another on a device and retain separate
token stores. Feature branches start from `develop`; promote reviewed work to `main`.
The workflow routing does not itself enforce branch protection or required reviewers.

The Dev service currently routes `/v1/*`, `/health` and `/ready`. Neither the public
homepage nor `/docs` is published by this deployment. The next product implementation
after hosted-Dev acceptance remains **2.7 — partial companion package**.

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

- [ ] Confirm hosted Dev on cellular: Dev indicator, sign-in, trip/check-in, refresh and logout with the Mac backend stopped (5.2a).
- [ ] Set up Appium and verify a physical-iPhone automation session (2.8a).
- [ ] Add and run existing-screen Appium regression tests (2.8b).

- [ ] Confirm the Google account chooser on iPhone after the Managed Login upgrade.
- [ ] Profile: save → reopen → edit → clear.
- [ ] Companions: create → edit → delete; verify account switching.
- [ ] Trips: create with companions → reopen → edit → review a conflict → delete.
- [ ] Check-in: save → reopen → clear; edit the trip and verify stale-context reconfirmation.
- [ ] Run the complete trip journey after check-in and packages are built (2.8).

The installed Dev build targets the hosted API. The Local build still requires the Mac's
LAN backend. Drafts and pending requests remain in memory; durable offline use and a
hosted production API are still future work.

## Details and maintenance

The backend and iOS `AGENTS.md` files retain detailed scope, technical constraints, acceptance
criteria and historical evidence. Feature guides are in iOS `docs/traveler-profile.md`,
`docs/companions.md`, and `docs/trips.md`; the AI requirement is in backend
`docs/ai-trip-planning.md`.

Keep `ROADMAP.md` in both repositories synchronized whenever a milestone changes. Move a feature
from **Built · verify** to **Complete** only when its required acceptance evidence is recorded.
