# PipPipGo roadmap — simple travel organizer

Rebaselined September 28, 2026 to the [simple product scope](docs/simple-travel-organizer.md).

| Milestone | Implementation | Acceptance |
| --- | --- | --- |
| 1 · My Profile | Name, age, home town, optional interests/notes; saved edits | Source implemented; device acceptance pending |
| 2 · Companions | Add/edit/delete reusable companions; referenced-person deletion protection | Source implemented; device acceptance pending |
| 3 · Trips | Traveler selection, ordered destinations, hotel stays, plane/train/car details, edit/delete | Source implemented; device acceptance pending |
| 4 · Reliable delivery | Versioned persistence, immutable retries, conflict review and account reset | Backend/iOS checks recorded in implementation notes; Dev revision 9 deployed; phone acceptance pending |

Preserve Google/Cognito sign-in, ECS/DynamoDB, account isolation and existing data.
Keep AI credentials and GPT-6 Luna configuration (user selected September 29, 2026). Optional Ask Pip chat supports travel questions, follow-ups and revisions to chat plans. Chat messages/history and the authorized traveler profile are shared; saved companions and trips stay separate.
The prior [traveler-intelligence roadmap](docs/archive/2026-09-28-traveler-intelligence-ROADMAP.md) is historical, not an active implementation queue.

Backend deployed to `https://dev.pippipgo.com` from `e1e3d2a` through successful run [36391002936](https://github.com/alikian/pippipgo-backend/actions/runs/36391002936). ECS revision 9 is stable; HTTPS health/readiness and unauthenticated organizer protection passed. Device installation and authenticated phone acceptance remain pending.

Destination-editor crash fix: preserve the trip draft across navigation and use stable destination bindings. 49 simulator tests and signed Dev build passed; fixed Dev app relaunched on the affected simulator. Interactive/device acceptance remains pending.

Destination controls simplified: swipe-to-delete and Add opens the form immediately; ordering remains available through a long-press menu. Dev device/simulator builds passed.

Google profile photo added to home with fallback and account-switch fencing. Cognito picture mapping deployed in place; 50 iOS tests and Dev builds passed. User confirmed Google photo works. Home title and Sign out now share a compact row; Dev builds passed.

Companions moved into Profile with a compact home-card summary and in-trip Add someone. 50 simulator tests and Dev builds passed; simulator updated.

Home companion summary displays up to three names, followed by +N for additional companions. Dev device/simulator builds passed.

Ask Pip: 105 backend tests (1 skipped), 51 iOS tests, signed Dev/simulator builds and synthetic live conversation/revision/off-topic checks passed. Deployed to Dev as stable ECS revision 11 through run 36397771743; updated simulator app installed. Phone acceptance pending.

Assistant Markdown rendering added; 52 simulator tests and Dev builds passed. Optional trip budgets and estimated/actual category costs are implemented; 109 backend tests (1 skipped), 53 simulator tests and Dev builds passed. Budget API deployed to Dev through successful run 36400462253 (ECS revision 12); simulator app updated. Phone acceptance pending.

Ask Pip → review → Save: new trip drafts prefill destinations, dates, notes and budgets; existing trips stay separate. 111 backend tests (1 skipped), 54 iOS tests, signed Dev/simulator builds and synthetic live schema checks passed. Deployed through run 36401831517, ECS revision 13; simulator app updated. Physical-device acceptance pending.

Party size fix: retain adult/child counts independently of named companions, recover explicit counts in older draft notes, and show everyone in Who is traveling. 113 backend and 55 iOS tests plus synthetic inference and Dev builds passed. Deployed through run 36402973166; ECS revision 14 stable and simulator app updated. Physical-device acceptance pending.

Talk to Pip live voice: `gpt-live-1` streaming audio/captions with server-owned credentials and GPT-6 Astra delegation; bounded sessions, account fences and iOS audio cleanup implemented. 133 backend tests (1 skipped), 56 simulator tests, Ruff checks and signed Dev iPhone build passed. Real OpenAI access and synthetic audio inference passed. Backend deployment, public WebSocket verification and physical-device voice acceptance remain pending; see [live voice evidence](docs/live-voice.md).

Voice-button visibility: Talk to Pip now appears on the organizer home and in fixed Ask Pip controls; voice opens in a dedicated sheet. 56 simulator tests and the signed Dev build passed. Installation is pending coordinated backend deployment; automatic approval review requires explicit approval for the develop push/deployment. No remote mutation occurred.

Approved voice rollout: backend `c196372` deployed through [run 36521766502](https://github.com/alikian/pippipgo-backend/actions/runs/36521766502); ECS revision 15 stable, health/readiness and unauthenticated chat/voice protection passed. Signed Dev app with visible home/chat Talk to Pip buttons installed and launched on Ali’s iPhone. Physical voice conversation acceptance remains pending.

Silent-voice investigation: full relay synthetic audio/caption inference passed. Added iOS microphone-level feedback, capture-stall detection and permission/interruption lifecycle fixes; 57 simulator tests and signed Dev build passed. Update installed on Ali’s iPhone; launch blocked by locked device. Reported physical speech silence remains unverified pending an unlocked-device check.

Voice greeting: each session opens with “Hi, I’m Pip, your travel companion.” Real-provider silent-input test returned the exact greeting and audio; 133 backend tests (1 skipped), Ruff and CI passed. Deployed `ca3dfe8` through run 36523013127, ECS revision 16 stable. No app reinstall needed.

Microphone capture fixed: reproduced zero-buffer timeout on Ali’s iPhone, added an explicit voice-processing input sink, and passed the same physical capture test (0.649 s). 57 simulator tests and clean signed Dev build passed. Update installed; normal launch blocked by the phone relocking. Full spoken-conversation acceptance remains pending.

Audio-session threading: moved Talk to Pip activation/deactivation off the main thread with serialized ownership and cancellation fences; 59 simulator tests and signed Dev build passed. Device logs no longer show the main-thread warning. Capture still times out with both new and original activation timing, including after AirPods disconnection; prior one-off capture success is not reliable acceptance. Physical conversation remains unresolved.


September 29 threading fix: clean signed Dev app installed on Ali’s iPhone. Automatic normal launch failed with a CoreDevice remote-service connection error; open the installed app manually.

iPhone 16 Pro Max comparison: iOS 27.0 reproduces the full capture timeout. Minimal plain and voice-processed microphone tests pass (0.382 s / 0.841 s) using the same activation helper, narrowing the failure to the combined app audio graph. Exact cause and full conversation acceptance remain unresolved; unsuccessful graph experiments were reverted.

The comparison app was rebuilt in a fresh output directory after an incremental build had an invalid asset signature. The clean signed Dev build and signature verification passed; installed on Akiphone. Normal launch was denied because the phone had locked. Manual Talk to Pip acceptance remains pending.

Voice capture repair: physical comparisons isolated the final mixer/output connection ordering. Explicitly connect the mixer to device output after attaching Pip’s player; remove the redundant sink and read the input format after graph setup. The production capture pipeline and three sustained playback/restart cycles pass on iPhone 16 Pro Max; 59 simulator tests pass. Installed-app greeting and spoken response acceptance remains to be confirmed.

The same capture fix also passes first-buffer and three sustained playback/restart checks on iPhone 12 (focused rerun after an activation error). Fresh signed Dev build verified, installed and launched on iPhone 16 Pro Max; manual greeting/reply confirmation requested.

The verified fix is installed on both physical phones. Akiphone launched successfully; normal launch on Ali’s iPhone 12 was denied after it relocked. User confirmation of the updated Akiphone greeting and spoken reply is pending.

User accepted working voice conversation on iPhone 16 Pro Max. Voice captions now use live conversation bubbles (Pip left, traveler right), timestamp-based grouping that supports overlapping speech, bounded transient retention, automatic scrolling with a manual-history mode, and fixed call controls. 62 simulator tests plus signed Dev build/signature verification passed; light/dark previews visually checked.

The chat-bubble Dev app is installed on Akiphone. Normal launch was denied because the phone had locked; open PipPipGo manually to use the updated conversation view.

GPT-6 Luna selected September 29: typed Ask Pip and voice reasoning now use `gpt-6-luna`; audio retains `gpt-live-1`. Synthetic live structured inference and Live session acceptance passed. 133 backend tests (one skipped), Ruff and CI passed. Dev commit `de4298f` deployed through [run 36541532191](https://github.com/alikian/pippipgo-backend/actions/runs/36541532191); ECS revision 17 is steady, health/readiness return 200 and unauthenticated access returns 401. IAM unchanged; no app rebuild required. Physical-device acceptance of Luna remains pending.

Locked-screen voice: established Talk to Pip sessions now continue in the background with audio mode enabled in all app configurations. 62 simulator tests and signed Dev build passed; installed on Akiphone. Five-minute session limit and explicit/interrupt cleanup remain. Physical locked-screen speech acceptance pending.

Full traveler profile in voice: all saved name, age, hometown, interests and notes are sent without truncation at session start. 135 backend tests (one skipped), Ruff and real-provider session acceptance passed. Dev `c82188f`, [run 36542495094](https://github.com/alikian/pippipgo-backend/actions/runs/36542495094), ECS revision 18 steady; public health/readiness passed. No app reinstall needed; spoken profile recall remains a device acceptance check.

Saved trips in voice: explicitly authorized September 29; trip details now included read-only at session start. 135 backend tests (one skipped), Ruff, live synthetic Luna flight recall and signed Dev build passed; disclosure update installed on Akiphone. Backend `a066f88` deployed through [run 36543283464](https://github.com/alikian/pippipgo-backend/actions/runs/36543283464), ECS revision 19 steady and health/readiness 200. Spoken saved-trip recall on the phone remains to be confirmed.

Companion and session lifecycle rollout: companion context `9f69d87` deployed through run 36544111413 (ECS revision 20); signed disclosure update installed on Akiphone. Session presence `9ec9f06` deployed through [run 36545154254](https://github.com/alikian/pippipgo-backend/actions/runs/36545154254), ECS revision 21 steady and health/readiness 200. 142 backend tests (one skipped), Ruff and CI checks passed. Real relay silence test asked “Are you still there?” and closed at 52.3 seconds; final synthesized goodbye test gave one farewell and closed at 16.9 seconds. Physical-device acceptance remains pending.

Goodbye recognition fix: `07905fc` deployed successfully through [run 36546544327](https://github.com/alikian/pippipgo-backend/actions/runs/36546544327), ECS revision 22 steady and health/readiness 200. 157 tests (one skipped), Ruff and real-provider natural sign-off closure passed. User-specific phone recheck remains pending.
