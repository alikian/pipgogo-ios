# Talk to Pip — GPT-Live

Requested September 28, 2026. The organizer home and fixed Ask Pip controls have a Talk to Pip button opening a dedicated voice sheet. The sheet includes an explicit Start voice conversation control, live user/assistant captions, streamed speech, and End voice. Typed Ask Pip uses GPT-6 Luna (selected September 29, 2026). Voice uses `gpt-live-1`, Marin, mono PCM16 at 24 kHz and GPT-6 Luna Responses delegation without tools. Native AVAudioEngine voice processing handles microphone/speaker echo cancellation. Voice and typed requests cannot run together.

The app opens `wss://<backend>/v1/travel-chat/live` with the existing Cognito access token in the Authorization header. The backend verifies identity, the retained account-disable fence and the existing daily AI quota before opening OpenAI's Live WebSocket. No OpenAI credential reaches iOS. Each session is limited to five minutes; credentials and account state are checked every 15 seconds. The existing server environment/Secrets Manager key and IAM grant are reused. No new infrastructure resource is required.

Only allowlisted profile fields and bounded prior chat text seed the session. Saved trips are included as read-only context at the user’s September 29 request. Saved companions are also included at the user’s subsequent September 29 request, with selected companions resolved for each trip. Structured chat drafts remain excluded. All saved traveler profile fields (name, age, hometown, interests and notes) are included in full, bounded by the organizer schema. Prior chat text has a separate 6,500-byte budget so a long profile does not displace all conversation history. Provider storage is disabled. Audio and captions are neither logged nor saved by PipPipGo. Captions disappear when the chat closes or the account resets. A voice session cannot write organizer data; saving a plan uses typed chat and the existing explicit review/Save flow.

The backend only accepts PCM audio appends and session close, so a client cannot change the model, instructions or tools. It filters outgoing events to audio/captions and closes the provider connection on cancellation, disconnect, account disable or timeout. The app stops capture/playback on chat dismissal, account reset, interruption and headphone disconnection. As requested September 29, an established voice conversation continues during screen lock/backgrounding using the audio background mode; an unfinished connection is cancelled when entering the background. Slow input/output queues terminate instead of accumulating stale audio. It does not reconnect or resume microphone capture automatically.

## Verification and release boundaries

- Model agreement: user explicitly requested GPT Live; `gpt-live-1` used, GPT-6 Astra preserved.
- Account access: existing Dev OpenAI secret successfully opened and closed a real GPT-Live session.
- Live inference: the full configured session accepted synthetic speech asking for Paris travel help; returned 602,880 audio bytes, eight input-caption events and ten output-caption events, with zero provider errors. This verifies OpenAI audio inference, not a deployed app connection or physical microphone quality.
- Backend validation: 133 tests passed, one skipped; Ruff checks/format passed. Mocked voice cases include authorization, disabled accounts, context filtering, injected commands, audio validity, normal close, abrupt disconnect, active-account deletion and session expiry.
- iOS validation: 56 simulator tests passed; signed Dev iPhone build passed. These do not establish physical-device voice acceptance.
- Deployment/IAM: user approved rollout. Backend commit `c196372` deployed successfully through [run 36521766502](https://github.com/alikian/pippipgo-backend/actions/runs/36521766502), ECS revision 15, CloudFormation UPDATE_COMPLETE and ECS steady state. No IAM change was needed. Public health/readiness passed; unauthenticated chat returned 401 and voice WebSocket returned 403. Authenticated audio through the public ALB remains a device acceptance check.
- Physical-device acceptance: pending. Check speaker/headphones, two-way speech and interruptions, backgrounding, network loss, microphone denial, account switching, five-minute expiry and Cognito expiry. Run the organizer multi-destination acceptance scenario as a regression.

## Rollout

Deploy the backend containing `/v1/travel-chat/live` using the existing CloudFormation-managed ECS delivery workflow. Verify authenticated WebSocket upgrade and a synthetic audio exchange through the public ALB before releasing the app. Keep request payloads and Authorization headers out of proxy/application logs. Then install the signed Dev app and perform the physical-device checks above. The endpoint is now deployed to Dev. The signed app with home and fixed-chat Talk to Pip buttons was installed and launched on Ali’s iPhone (`00008101-0009498E2647001E`). Physical microphone/conversation acceptance is still pending.

## Official protocol references

- [GPT-Live WebSockets](https://developers.openai.com/api/docs/guides/voice-websockets)
- [Session configuration and captions](https://developers.openai.com/api/docs/guides/live-conversations)
- [Responses delegation](https://developers.openai.com/api/docs/guides/live-delegation)

September 28 visibility follow-up: the previous build had not been installed on the phone, and chat auto-scroll could hide the inline voice section. The updated home/fixed buttons passed 56 simulator tests and a signed Dev build. Automatic approval review blocked the develop push/deployment pending explicit user approval; no push, deployment or phone installation occurred.

Approved rollout completed September 28: the earlier approval block was resolved by the user. Dev deployment succeeded, the phone app was installed, and `devicectl` confirmed successful launch. Tap Talk to Pip below Ask Pip, then Start voice conversation.

## Silent Listening investigation — September 28

User reported Listening with no spoken response. Dev logs confirmed authenticated voice connections were accepted. A synthetic speech test through the full local backend relay and real GPT-Live provider returned 147 audio events, nine input-caption events and 15 output-caption events with normal closure. This isolates a working relay path but does not establish physical microphone capture.

The iOS update adds a live microphone level and capture watchdog, labels the state Starting microphone until the first captured buffer, allows the permission prompt's temporary inactive state, and handles only beginning audio interruptions as a stop. 57 simulator tests and signed Dev build passed. Installed on Ali’s iPhone; iOS denied launch because the phone is locked. Physical speech input and the root cause of the reported silence remain unverified; the user has been asked whether captions appear and whether testing is on the phone or simulator.

## Spoken greeting

Each new voice session now says “Hi, I’m Pip, your travel companion.” once, then listens. The backend sends the instruction after the first microphone audio packet so the GPT-Live timeline is advancing. A real-provider test with only silent input returned that exact caption and 132 audio events. 133 backend tests (one skipped), Ruff checks and CI passed. Commit `ca3dfe8` deployed through [run 36523013127](https://github.com/alikian/pippipgo-backend/actions/runs/36523013127); ECS revision 16 reached steady state and public health/readiness passed. No app reinstall is needed for this backend change. Physical microphone/speaker acceptance remains separate.

## Microphone input graph fix — September 28, 23:50 PDT

The user's capture-timeout screenshot was reproduced by a physical iPhone regression test: the original input tap returned no PCM buffers within four seconds. Connecting the voice-processing input to an explicit `AVAudioSinkNode` keeps the microphone graph rendering before assistant playback; the identical physical test then passed in 0.649 seconds. The PCM converter separately produced valid output from synthetic input. The timeout copy no longer claims that another call caused the failure.

Validation: one physical capture regression passed, all 57 simulator tests passed, and a clean signed Dev build passed signature verification. Installed on Ali’s iPhone; the final normal launch was denied because the phone had relocked. The user can unlock and open the installed app. This verifies physical capture-buffer delivery, not yet a complete user-spoken conversation or speaker quality. The automated capture test saves/uploads no audio and is compiled only for physical-device test destinations.

Reference: [Apple AVAudioSinkNode documentation](https://developer.apple.com/documentation/avfaudio/avaudiosinknode).

## Audio-session threading — September 29

Moved Talk to Pip category/activation/deactivation to one serial background queue, with call ownership checks to prevent stale cleanup deactivating a replacement call. Startup awaits activation and checks cancellation before creating the audio graph. The graph is initialized after activation; stopping before startup no longer creates an engine. This supports the iOS 17 deployment target; the SDK's native asynchronous activation/deactivation APIs require iOS 27.

Validation: 59 simulator tests passed, including off-main execution, stale cleanup and stopped-start cancellation; the signed Dev build passed. Physical capture runs no longer emitted the reported AVAudioSession main-thread warning. However, physical capture timed out repeatedly, initially on the AirPods HFP route and again after the user disconnected AirPods. A control using original synchronous main-thread activation and the existing input sink also timed out and reproduced the warning. A muted mixer experiment did not resolve capture and was reverted. The earlier single passing microphone test is therefore not sufficient evidence of a reliable fix. Full physical capture/conversation acceptance remains unresolved. No recorded speech was saved or uploaded during these tests.

September 29 threading fix: clean signed Dev app installed on Ali’s iPhone. Automatic normal launch failed with a CoreDevice remote-service connection error; open the installed app manually.

## iPhone 16 Pro Max comparison — September 29

User requested testing on the connected iPhone 16 Pro Max, Akiphone (`00008140-001405023E88801C`), running iOS 27.0 build 24A437. The Talk to Pip capture test failed repeatedly with the same four-second no-PCM timeout after microphone permission was granted. Two minimal controls passed: a basic AVAudioEngine input tap (0.382 s) and a tap with voice processing enabled (0.841 s). These controls use the same audio-session activation helper. This isolates a difference in the app's combined input/playback/conversion graph; it does not yet identify the exact faulty operation or prove an OS defect.

Explicit output formatting, removing the input sink with a default-format tap, and keeping playback supplied with looped silence did not fix the full capture test. These experiments were reverted. Retained physical-only tests now compare basic capture, voice-processed capture and the full production pipeline, and request microphone permission on a new test device. They retain/upload no microphone audio. No backend runtime change was made.

The comparison app was rebuilt in a fresh output directory after an incremental build had an invalid asset signature. The clean signed Dev build and signature verification passed; installed on Akiphone. Normal launch was denied because the phone had locked. Manual Talk to Pip acceptance remains pending.

## Full-duplex output connection fix — September 29

User confirmed the normal iPhone 16 Pro Max app also timed out. Dev WebSocket connections were accepted at 07:48:58, 07:51:02 and 07:54:02 UTC; this does not by itself prove audio delivery. A controlled physical-test matrix then isolated the app graph: adding a player with automatic mixer output failed at both 24 kHz and the native output sample rate, while explicitly reconnecting the final mixer output **after attaching the player** passed (0.716 s). An earlier explicit-output experiment had connected the mixer before the player and did not resolve capture.

Production startup now creates the voice-processing input, attaches the 24 kHz player, explicitly connects the main mixer to the output using its native format, and only then reads the input format and installs its tap. The redundant sink was removed. The real PCM pipeline passed on Akiphone in 0.580 s, followed by three successive starts delivering at least two seconds of 24 kHz PCM each while scheduling silent playback (7.902 s total). All 59 simulator tests passed. Physical tests retain/upload no recorded audio. The added sustained-capture regression exercises playback and teardown/restart, not merely first-buffer delivery. Full provider greeting and user-spoken response acceptance remains separate until confirmed on the installed app.

Additional device validation: Ali’s iPhone 12 passed first-buffer capture (0.632 s). Its first sustained run encountered an AVAudioSession activation error; a focused rerun passed all three sustained playback/restart cycles in 7.768 s. A fresh signed Dev build passed signature verification and was installed and launched successfully on Akiphone. The user has been asked to confirm the greeting and a spoken reply in the updated app.

The verified fix is installed on both physical phones. Akiphone launched successfully; normal launch on Ali’s iPhone 12 was denied after it relocked. User confirmation of the updated Akiphone greeting and spoken reply is pending.

## Conversation acceptance and caption bubbles — September 29

The user confirmed on Akiphone that voice conversation now works (“talk is fine”) and requested chat-style message bubbles. This records successful user-spoken conversation acceptance after the output-connection repair; other physical scenarios listed above remain separate.

Live captions now appear as chronological message bubbles: Pip on the left, the traveler in blue on the right. Speech fragments grow within their bubble; each speaker is grouped independently using provider timeline intervals, including overlap and delayed delivery. A gap of more than 1.2 seconds starts a new bubble for that speaker; these are display boundaries, not provider-defined completed turns. Original fragment text/timing is retained within bounded transient memory (8,000 characters, 64 bubbles, 512 fragments). Starting a new session or closing the sheet clears the transcript. Nothing is added to saved typed-chat history.

The conversation fills a scrollable area with fixed microphone/start/end controls. New captions follow the latest message until the user drags to read earlier messages; “Latest messages” resumes following. Light and dark synthetic conversation previews were visually checked. The temporary simulator launch route was removed before the phone build; the reusable Xcode preview remains debug-only. All 62 simulator tests passed, including overlap, late fragments, timestamp ordering, exact repeated words, clearing and bounded retention. Signed Dev build and signature verification passed. The backend relay already includes transcript intervals, so no backend runtime deployment is needed.

Protocol reference: [Managing GPT-Live sessions — transcript deltas](https://developers.openai.com/api/docs/guides/live-conversations).

The chat-bubble Dev app is installed on Akiphone. Normal launch was denied because the phone had locked; open PipPipGo manually to use the updated conversation view.

## September 29 model change

The user selected `gpt-6-luna` for typed Ask Pip and voice Responses delegation.
A synthetic travel question returned a valid live Luna structured reply, and a real
OpenAI Live session accepted the full `gpt-live-1` configuration with Luna delegation.
The session was closed without audio; this does not verify an executed delegated
response or physical-device Luna acceptance. Existing credentials/IAM are reused.
Backend checks: 133 passed, one skipped; Ruff lint/format and hosting template lint passed.

GPT-6 Luna selected September 29: typed Ask Pip and voice reasoning now use `gpt-6-luna`; audio retains `gpt-live-1`. Synthetic live structured inference and Live session acceptance passed. 133 backend tests (one skipped), Ruff and CI passed. Dev commit `de4298f` deployed through [run 36541532191](https://github.com/alikian/pippipgo-backend/actions/runs/36541532191); ECS revision 17 is steady, health/readiness return 200 and unauthenticated access returns 401. IAM unchanged; no app rebuild required. Physical-device acceptance of Luna remains pending.

## Screen-lock continuation — September 29, 2026

Enabled `UIBackgroundModes: audio` in Debug and Release app plists and retained
established voice sessions on background transitions. The existing play-and-record
voice-chat audio session supports continuous microphone/speaker use with the screen
locked. The voice sheet explains this behavior. End voice, dismissal, account reset,
interruptions, headphone removal and the server five-minute limit still end sessions.
Removed a duplicate microphone permission plist key so the live-voice explanation
is the single declared permission message. Simulator regressions and signed Dev build
passed; physical locked-screen conversation acceptance remains pending.

## Complete profile — September 29, 2026

At the user’s request, live voice now receives all five saved traveler fields in full:
name, age, hometown, interests and notes. Removed the 1,200-byte per-field cutoff;
the persisted organizer schema still bounds field lengths. Prior chat has an independent
6,500-byte budget. Internal record IDs, saved companions/trips and unknown fields stay
excluded. Profile edits are picked up when the next voice session starts.
135 backend tests passed (one skipped), including exact long multilingual profile
preservation with chat history; Ruff passed. OpenAI accepted a real Live session
with an 11,194-byte synthetic profile context; no audio was sent. This is session
acceptance evidence, not spoken profile-recall or physical-device acceptance.

Full traveler profile in voice: all saved name, age, hometown, interests and notes are sent without truncation at session start. 135 backend tests (one skipped), Ruff and real-provider session acceptance passed. Dev `c82188f`, [run 36542495094](https://github.com/alikian/pippipgo-backend/actions/runs/36542495094), ECS revision 18 steady; public health/readiness passed. No app reinstall needed; spoken profile recall remains a device acceptance check.

## Saved-trip voice context — September 29, 2026

The user requested access to saved trips in voice. Each new session includes the
authenticated account’s trip names, destinations/dates, hotels, transport, party counts,
budgets and notes. Internal trip/companion references and saved companion records are
excluded. Trips are a read-only snapshot; voice cannot silently edit organizer data.
The shared prompt now permits supplied trip context, while typed chat continues to
receive only its existing context. The iOS disclosure now names saved trips.
135 backend tests (one skipped), Ruff and CI checks passed, including trip inclusion
and cross-account isolation. A live Luna Responses check recalled the synthetic
saved flight AF123 from the exact context; this does not prove a spoken GPT-Live
response on the phone. Signed Dev app built, signature verified and installed on Akiphone.

Saved trips in voice: explicitly authorized September 29; trip details now included read-only at session start. 135 backend tests (one skipped), Ruff, live synthetic Luna flight recall and signed Dev build passed; disclosure update installed on Akiphone. Backend `a066f88` deployed through [run 36543283464](https://github.com/alikian/pippipgo-backend/actions/runs/36543283464), ECS revision 19 steady and health/readiness 200. Spoken saved-trip recall on the phone remains to be confirmed.

## Saved companions — September 29, 2026

User authorized companion context. New sessions include every saved companion’s
name, age, hometown, interests and notes, plus each trip’s selected companion details.
Unselected companions remain available in the general list but are not treated as
traveling on every trip. Internal person IDs and unknown fields are excluded. This
is read-only context; typed chat still receives its existing context.
135 backend tests (one skipped), Ruff and CI checks passed. Tests cover selected versus
unselected companions, complete fields and account isolation. Live Luna synthetic
context recalled the selected Sam and their train preference. This checks reasoning
recall, not physical spoken acceptance. Signed Dev build passed and the updated
sharing disclosure was installed on Akiphone.

## Session presence and goodbye — September 29, 2026

After 30 seconds without transcribed user speech or assistant output, the backend
asks Pip to say “Are you still there?” once. It waits 15 seconds after the check-in’s
last output for a user reply, then closes both connections. A reply resets the timer;
continuous silent microphone packets do not count as speech. No timer starts before
capture begins. A short explicit English farewell (for example “bye”, “goodbye Pip”,
or “see you later”) followed by a two-second pause requests a brief goodbye and ends
after playback drains, bounded to 12 seconds. Incidental mentions such as “How do I
say goodbye in French?” do not trigger closure; resumed speech cancels pending closure.
Five-minute maximum and account/interruption cleanup remain. Transcript fragments
used by this policy stay transient and bounded.
142 backend tests (one skipped) and Ruff passed, including policy timing, replies,
fragmented/corrected goodbyes, long assistant speech and relay close cleanup.
Implementation follows [OpenAI live session controls](https://developers.openai.com/api/docs/guides/live-conversations).

Real-provider relay acceptance: continuous silent PCM produced the greeting and
“Are you still there?”, then closed automatically at 52.3 seconds with zero errors.
Synthesized “Goodbye, Pip” was transcribed and closed at 18.8 seconds with zero errors.
An initial check exposed continuously emitted silent output packets; those are now
excluded from activity using PCM energy, with a regression test. The final farewell
instruction avoids repeating a goodbye the model has already spoken. These are
synthetic live checks; physical-device silence/goodbye acceptance remains pending.

Companion and session lifecycle rollout: companion context `9f69d87` deployed through run 36544111413 (ECS revision 20); signed disclosure update installed on Akiphone. Session presence `9ec9f06` deployed through [run 36545154254](https://github.com/alikian/pippipgo-backend/actions/runs/36545154254), ECS revision 21 steady and health/readiness 200. 142 backend tests (one skipped), Ruff and CI checks passed. Real relay silence test asked “Are you still there?” and closed at 52.3 seconds; final synthesized goodbye test gave one farewell and closed at 16.9 seconds. Physical-device acceptance remains pending.

## Goodbye recognition correction — September 29, 2026

User reported goodbye did not end their conversation. Exact user transcript was not
available. The prior exact-phrase detector missed “good bye”, polite lead-ins and
a goodbye attached to an earlier sentence; whitespace-only transcript fragments
were also discarded. Recognition now preserves fragment spacing and matches natural
explicit farewells in the final sentence, while excluding incidental mentions,
negations and corrections. 157 tests passed (one skipped), Ruff passed. A real relay
check transcribed “Okay, thank you for your help. Goodbye, Pip”, gave a farewell and
closed at 18.8 seconds from session start with no provider errors. This does not
establish acceptance of the user’s exact failed utterance; device recheck remains.

Goodbye recognition fix: `07905fc` deployed successfully through [run 36546544327](https://github.com/alikian/pippipgo-backend/actions/runs/36546544327), ECS revision 22 steady and health/readiness 200. 157 tests (one skipped), Ruff and real-provider natural sign-off closure passed. User-specific phone recheck remains pending.
