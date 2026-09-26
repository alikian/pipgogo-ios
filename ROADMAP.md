# PipGoGo roadmap

**Current stage: basic trip flow · Next: 2.6 — Pre-trip check-in**
Updated September 26, 2026 · [Project time log](TIME_LOG.md)

**Total logged time: 6 hours 29 seconds** · 6 hours estimated + 29 seconds recorded; see the time log for scope.

| Available on the iPhone | Still to build |
| --- | --- |
| Google sign-in, traveler profile, companions, trip creation/editing/deletion | Check-in, trip packages, AI planning, durable offline mode |

**Progress:** 5 of 8 Step 2 milestones implemented. AI planning: 0 of 6 Step 3 milestones implemented.
**Latest verification:** 85 iOS tests and 10 focused backend regression checks passed; signed build installed on the iPhone.

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
| 2 · Basic trip flow | 🟡 In progress | 2.1–2.5 implemented; check-in, packages and integrated acceptance remain |
| 3 · AI planning & guidance | ○ Planned | Provider, Plan with AI, refinement, saving, device acceptance and verified arrival guidance |
| 4 · Offline use | ○ Planned | Durable local storage, pending-write queue, synchronization and offline packages |
| 5 · Production readiness | 🟡 Foundation ready | AWS auth/data infrastructure deployed; API hosting, monitoring, hardening and operational checks remain |
| 6 · Traveler pilot | ○ Planned | Validate San Diego airport → accommodation, then test with 5–10 travelers |

## 2 · Basic trip flow

| Milestone | Feature | Status | What remains |
| --- | --- | --- | --- |
| 2.1 | Shared authenticated API client | ✅ Complete | Preserve safe retry/version behavior in new features |
| 2.2 | Traveler profile | 🟡 Built · verify | Device save, reopen, edit and clear |
| 2.3 | Companions | 🟡 Built · verify | Device create/edit/delete and account switching |
| 2.4 | Trip list & creation | 🟡 Built · verify | Device create/reopen with selected companions |
| 2.5 | Trip editing & deletion | 🟡 Built · verify | Device edit, conflict review and confirmed deletion |
| **2.6** | **Pre-trip check-in** | **➜ Next** | Review the trip, record requests/concerns, confirm its current version |
| 2.7 | Partial trip package | ○ Planned | Generate, list, display and download packages; clearly label missing live guidance |
| 2.8 | Integrated device acceptance | ○ Planned | Verify profile → companions → trip → edit → check-in → package |

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

## Device checks still open

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
