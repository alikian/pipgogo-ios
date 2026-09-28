# Pip — master implementation prompt for Codex

Copy this entire prompt into Codex with access to the existing iPhone app and AWS ECS backend repository. The source product document is [Pip Traveler Intelligence — Getting to Know You & Adaptive Travel](https://docs.google.com/document/d/164nFTLecPZiQzFRrEpG5t7EdcgccPwT7vpfgf5Kz29o/edit). This prompt translates that document and the latest screen feedback into implementation instructions. Inspect the live repository and document before editing; adapt names and interfaces to the actual code. If the document has changed, preserve its newer decisions.

## Your job

You are the lead iOS, backend, AI, and product engineer for Pip, a conversational travel companion represented by a small traveling duck. Build the next usable vertical slice in the **existing native iPhone application and deployed AWS ECS backend**. Google authentication and authenticated app-to-backend communication already exist. Reuse them. Do not replace the app, authentication, backend, or data conventions without a concrete defect or security reason.

Pip should know the traveler across trips, understand the current journey, help organize bookings and transportation, create a light personalized plan, and improve the **current trip** as it learns. The product promise is: **“Pip travels with me, understands what matters, and gets more helpful as we go.”** Knowing more must lead to better choices, not more questions or a denser schedule.

This is an implementation task. Inspect the project, make the changes, run the meaningful checks available in the repository, and report what works and what remains. Do not stop after proposing architecture or a mockup. Work in the existing patterns, make focused changes, and avoid building future hardware or every possible integration before the core journey works.

## Priority and source of truth

1. Preserve current working authentication, user identity, API conventions, deployment setup, and established UI patterns unless they block these requirements.
2. Implement the latest trip intake direction below. An older milestone in the source document says to show “Mostly planned / Partly planned / Starting from scratch.” **Those are internal inferred planning states, not visible onboarding choices.** The latest section 27 and the actual screen feedback supersede that older milestone line.
3. Treat saved bookings and user-confirmed facts as more authoritative than AI extraction, inference, or suggestions. Trip-specific choices override reusable memory for this trip.
4. Keep the interface conversational, progressive, and calm. The app should ask only a question whose answer materially changes its next useful action.
5. Never make up a booking, flight, schedule, price, live status, accessibility fact, or traveler preference. Label estimates and provisional plans.

## First inspect and map the code

Find the iOS entry points for the current “Your trip” screen, sign-in/session state, chat/composer, trip models, persistence, API client, localization, and uploads. Find the ECS API routes, auth middleware, current user mapping, database/storage conventions, AI orchestration, and deployment/test scripts. Read repository instructions. Record a brief implementation map and identify which capabilities already work so you extend them instead of duplicating them. If the source Google Doc is not directly accessible from the coding environment, this prompt contains the operative requirements; do not block the build on a connector.

Implement in coherent vertical slices. After each slice, verify the real UI/API behavior and data ownership before moving on. Prefer existing infrastructure and interfaces. If an external flight, maps, weather, speech, or booking API is not configured, create a clean boundary and deliver a useful fallback without pretending live data exists. Do not hardcode a provider, fabricated result, or secret.

## Pip's character and conversation policy

Pip is curious, calm, friendly, multilingual, observant, concise, and comfortable with spontaneity. It is helpful without being intrusive, can change its mind, and is never judgmental. Avoid childish catchphrases, constant duck references, excessive emoji, fake intimacy, and repeated praise. A gentle mascot can still be a capable travel assistant.

Address the traveler by their **preferred name**, when known and appropriate. Add or use a `preferred_name` account/profile attribute that the traveler can edit. Never infer name or gender from email or OAuth display name as a final preference. If there is only an account display name, it may be offered for confirmation; until then use a natural name-free greeting. Use the preferred name occasionally, especially at the start of a session, and do not repeat it in every message. Address a group naturally without assuming the account holder is the only traveler. Respect language and pronouns the traveler explicitly provides; do not infer sensitive traits.

Conversation rules:

- Use current trip facts, prior answers, saved companions, and relevant Traveler Memory before asking anything. Do not ask twice for the same information.
- Acknowledge new information briefly, then ask **one** useful follow-up at a time. If enough is known, do something useful instead of continuing to interview the traveler.
- Let the traveler type, speak, attach something, say “I don't know,” skip, or correct Pip. A short answer is enough.
- Understand free-form answers; do not force travelers to translate their wishes into app-defined categories. Show a few concise suggestions only when they help, and always allow free-form input.
- Avoid repeating the full trip summary in every turn. Show a compact, editable summary only where it helps orientation or correction.
- When busy or moving, respond with a short actionable recommendation. Expand when the traveler asks why or wants to talk.
- Distinguish a question, a suggestion, an estimate, a confirmed booking, and an action that would change data or create a reservation.
- Do not claim that Pip has booked, canceled, contacted a provider, verified a live fact, or updated memory unless that action actually happened.
- Ask permission before saving a non-obvious persistent preference or applying a consequential plan change. Let explicit corrections override inference immediately.

Build a conversation controller with a structured state and tools/actions, rather than one enormous unbounded prompt that fabricates state. Keep the character instructions separate from trip facts, verified data, safety rules, tool results, and response formatting. The model may propose actions; validated application code owns authorization, storage, and irreversible effects. Use structured outputs for extraction, next-question decisions, suggestions, and plan revisions; validate them server-side before persistence.

## Redesign the current “Your trip” screen

The uploaded screen currently has a large “Your trip” title, a redundant explanation card, New York City / Next long weekend / 3 days in a tall card, and a crowded “How much is already planned?” selector above “Anything already planned?” Replace that layout and flow.

The first view should have one clear heading, a compact editable trip summary, **one active question**, a simple response composer, and a clear action. Use the preferred name if confirmed, for example:

> Sara, let's plan New York  
> Next long weekend · 3 days  [Edit]  
> What have you already booked or decided?  
> Tell me in your own words, or add a booking.  
> [Type or speak] [Add a file or photo] [Nothing yet]  
> [Continue]

This is example copy, not a hardcoded identity, destination, or date. If a traveler has already told Pip about the hotel, flight, or event in chat or a prior step, summarize it and skip the duplicate question. If destination and dates are unknown, ask for those first. If “next long weekend” is ambiguous, offer a concrete date interpretation for confirmation rather than silently fixing it. Keep destination and timing editable. Do not repeat “Where are we going?” above a card that already contains the destination. Do not show all later fields on the first screen. The initial screen must fit comfortably on a normal iPhone without a wall of choices; dynamic type, VoiceOver, keyboard, and smaller device sizes must remain usable.

The “Mostly planned / Partly planned / Starting from scratch” states remain in the trip model if useful, but Pip infers and updates them from the traveler’s words and confirmed bookings. They are **never a required visible first-screen question**. Remove the redundant explanation card and the disabled “Anything already planned?” field. Use a single attachment entry point if separate buttons crowd the layout. When the user says “Nothing yet,” advance immediately; do not demand a document.

This page is an entrance to an intelligent conversation, not the complete trip form. After the answer, Pip decides what missing fact matters next. For example, if transport to New York is unknown, ask about flying/driving/train. If flights are confirmed, ask about the arrival transfer only when the answer is needed. If a hotel and flight are already present, use them without asking again.

## Trip intake and door-to-door journey

Trip intake should require only destination and exact or approximate dates to begin. Support saved companions, selected travelers, lodging, fixed commitments, travel mode, budget comfort, accessibility or dietary needs that users choose to share, and other constraints progressively. Let unknown optional details remain unknown. A useful early plan can be provisional; a time-specific arrival or departure plan needs verified or clearly estimated transport timing.

Ask naturally: “How are you getting there—flying, driving, train, or something else?” If flying, ask whether flights are booked. Provide **Upload flight confirmation**, **Enter flight details**, and **Find flights**. Support PDF, DOCX, photo/screenshot, camera capture, pasted text, and manual entry as the existing capability rollout permits. For an unbooked flight, provide an external flight search or booking link with origin, destination, dates, and party prefilled when the chosen provider supports it. Label the provider as external; Pip does not purchase a ticket merely by opening a link. Allow the traveler to return later and add the booking. Avoid collecting a precise home address unless needed for the transfer.

For booked travel, model outbound, connecting, onward, and return segments with origin/destination airports or stations, carrier, flight/train number, scheduled local departure/arrival times, time zones, date, terminal when available, connection, source, booking reference, confirmation state, and later status updates. Flight number alone does not establish the itinerary. Parse imports into **proposed** facts and show a concise review. The traveler accepts, edits, or rejects important facts before they become authoritative Trip Context. Keep source provenance and confidence; do not overwrite a confirmed booking with an extraction or estimate.

Plan the full door-to-door route in both directions when relevant:

1. Home or starting point → departure airport/station.
2. Arrival airport/station → hotel or first destination.
3. Hotel or last stop → departure airport/station for the return.
4. Arrival airport/station → home or final destination.

Ask which legs are already arranged. For missing legs, suggest a practical choice among rideshare/Uber, drop-off, parking, shuttle, public transit, taxi, rental car, walking, or other local modes. Use actual airports, terminals, landing times, group size, luggage, mobility needs supplied by the traveler, pickup rules, estimated duration/cost where real data exists, and realistic buffers for traffic, security, baggage, connections, and check-in. Label estimates and link to a provider when booking is external. Do not book or cancel a ride without a deliberate user action and confirmation.

Example: for San Diego → New York, Pip should determine how the traveler gets from home to SAN, which of JFK/LGA/EWR the flight reaches and when, and how to reach the actual hotel. It should repeat that reasoning for the return. Do not schedule activities while the traveler is in transit, before a plausible hotel arrival, or too close to airport departure. Respect time zones, overnight travel, hotel check-in/out, baggage, fatigue, and open time. If a flight changes, recompute affected transfers and proposed activities, explain material changes, and protect confirmed commitments.

Travel mode within the destination is separate from the mode of reaching it. Ask “How do you want to get around?” only when it changes the plan; a mixed answer is valid. Current-trip transport choices should not automatically become lifelong transportation preferences.

## Getting to know the traveler

Replace any static traveler-preference questionnaire with a short, optional conversation. For a new traveler, start with a natural introduction to Pip and ask about a trip, vacation, or day out they enjoyed: “What made it good?” Follow the answer, perhaps with one relevant clarifier. Explore roughly three areas when useful: what makes a great experience, what makes travel less enjoyable, and what they gravitate toward somewhere new. Do not display a fixed list of museums/food/shopping/nature or relaxed/moderate/fast as the opening experience. Do not demand a minimum response length.

After roughly three meaningful exchanges, normally stop: “That's enough for me to get started. I'll learn more as we go, and you can correct me anytime.” Offer Continue with my trip, Keep talking, or Skip. The traveler may start the trip with little memory. Returning travelers should load existing memory and skip the introductory interview. Briefly verify a major old preference only when relevant to this trip. Memory must remain editable and correctable in ordinary language.

Pip’s reasoning should extract meaning from a story rather than memorize keywords. “We wandered little streets with no schedule” may suggest spontaneous neighborhood discovery with **inferred** confidence. A follow-up can check that interpretation. The traveler saying “I generally dislike rigid itineraries” is an explicit preference. “I'm exhausted today” is temporary context. “I don't want sushi tonight” is a temporary choice, not a permanent dislike. One rejected recommendation is not a dislike. Repeated choices may increase confidence gradually, subject to context.

## Traveler Memory, trip context, and privacy

Use stable server-side `user_id` derived from the verified auth identity. If using Cognito federation, the Cognito subject may be the stable key; if validating Google directly, map its verified subject to an internal user ID. **Do not use email as the ownership key or trust a client-supplied user ID.** Enforce ownership on every trip, memory, conversation, companion, attachment, and plan request, including download paths. Protect tokens and uploaded booking information, and avoid logging sensitive material. Use existing encryption and storage conventions. Provide deletion/edit paths for memory and trip data consistent with the app’s current architecture; do not retain raw audio or images longer than necessary.

Separate:

- **Persistent Traveler Memory:** reusable tendencies such as interests, pace, discovery style, dislikes, food preferences, comfort, budget tendency, interaction style, and transportation preferences.
- **Trip Context:** destination, dates, companions, accommodations, flights, ground transfers, current-trip preferences, bookings, constraints, and reservations.
- **Temporary Context:** current energy, location, time, weather, fatigue, short-lived preferences, and disruptions.
- **Confirmed imported facts:** user-reviewed facts with source references; distinct from Pip suggestions.

Each memory item should contain category/key/value, source, original statement when useful, confidence, status (`explicit`, `confirmed`, `inferred`), scope (`persistent`, `trip_specific` or temporary state), timestamps, and a path for correction/deletion. A trip-specific override can supersede a general preference without destroying it. Explicit correction wins immediately: “You've got me wrong,” “that was just because I was tired,” “don't remember that,” or “only for this trip” must revise scope/confidence or remove the item. Do not infer allergies, disabilities, medical conditions, nationality, age, or other sensitive traits from behavior. Ask directly in neutral optional language only when needed; allow None and Prefer not to answer.

Store a confirmed preferred name separately from a traveler's full legal identity and use it across devices and languages. Do not repeat known profile questions on each trip. Keep saved companions and this trip's selected travelers distinct; the account holder can travel alone or with different groups.

## Planning and adaptation

Generate an initial plan when there is enough context to help, not when every optional field is filled. The planner input should include authenticated traveler, relevant memory, current trip, selected companions, confirmed imported facts, flights and ground legs, lodging, fixed commitments, trip constraints, existing plan, and current context when available. Return **structured plan items plus a short explanation**, not only prose. Mark each item as confirmed booking, imported commitment, or Pip suggestion; carry fixed status, time window, place, source, rationale, and proposed/accepted/rejected/completed/skipped state.

Internal planning state guides behavior:

- Mostly planned: preserve the existing schedule and help with gaps, transfers, or problems.
- Partly planned: protect confirmed commitments and fill useful gaps.
- Starting from scratch: propose a few anchor experiences and generous free time.

Fixed commitments outrank suggestions; confirmed facts outrank inferences; trip choices outrank general memory. Cluster nearby activities, account for travel time and opening hours when reliable data exists, and avoid backtracking. Do not fill every hour. Never silently move, remove, or cancel a reservation. A proposed change should show what stays, what moves/adds/removes, why, and whether acceptance is required. Let the user accept, reject, or correct the suggestion.

The itinerary is a living plan. When the traveler says “too much walking,” “I loved that market,” or “that museum wasn't for me,” interpret the signal carefully, revise future **suggestions in the current trip**, and propose a small useful adjustment. If a museum is booked, keep it unless the traveler explicitly changes it. “Too much walking today” should reduce the immediate walking load without recording a permanent mobility condition. Ask one short “what did you like?” follow-up only if the reason matters and isn't apparent. Do not announce database updates every time; better recommendations should make the learning visible.

The recurring loop is **understand → suggest → experience → learn → adapt**, across the current trip and later trips. Past preferences are helpful starting points, not permanent rules. On a new trip Pip can say, “Last time you enjoyed exploring neighborhoods without much of a schedule. Keep this one loose too?” and accept the answer.

## Multilingual and multimodal experience

The traveler chooses an app and conversation language. Pip can detect a message’s language where appropriate, respond naturally, and switch when requested. Keep the traveler’s language separate from the destination’s language; for example, Pip may converse in Farsi while translating Japanese for a local interaction. Memory follows the person across languages. Preserve original phrasing where useful alongside normalized meaning. Do not infer nationality or culture from language. Localize user-facing strings and design for longer translations and right-to-left layouts when the language is supported. Pip’s calm personality should survive translation.

The long-term interaction modes are text, photo upload, camera capture, voice recording, PDF/DOCX, and live voice with interruption. Keep one coherent conversation and shared trip context across all modalities. Use specialized transcription, OCR/vision, and parsing where helpful; normalize results into proposed facts and user intent. Request microphone/camera permission at use, show active listening/camera state, and avoid unconsented background recording. A single uncluttered composer can put less-used inputs behind an attachment control. Ship capability in practical slices: text first, then the media inputs actually needed to prove the travel flow; do not hold the useful trip experience hostage to complete live voice or wearable work.

## Suggested domain contracts (adapt to actual repository)

- `User`: stable server-side ID, verified auth mapping, preferred name, preferred language, locale.
- `TravelerMemoryItem`: category/key/value, original utterance/source reference, confidence, status, scope, timestamps.
- `Trip`: owner ID, destination, exact/approximate dates, inferred planning state, lifecycle state (`draft`, `intake_in_progress`, `ready_to_plan`, `planned`, `active`, `completed`), language override, notes.
- `TripTraveler`: linked saved companion or trip-only person, optional display name/relationship/age range/language/preferences/confirmed needs.
- `JourneyLeg` and `FlightSegment`: ordered outbound/onward/return legs, origin/destination, mode, carrier/number, local scheduled/updated times and zone, terminal/connection, booking and review status, source, luggage/access needs, ground transfer estimates and buffers.
- `TransportationPlan`: destination modes, rental/own-car facts, parking and pickup details, sources, confirmation state.
- `Accommodation`: property/address, check-in/out, reference, instructions, source, confirmation state.
- `Commitment`: fixed or flexible event, time/place, source, confirmation.
- `AttachmentImport`: ownership, storage reference, processing status, proposed facts, user decisions, provenance.
- `PlanItem`: time window, location, source and fixed status, acceptance/completion state, rationale.
- `TripFeedback`: raw feedback, interpreted signal, temporary flag, proposed memory change, context and timestamps.

Expose authenticated operations for create/read/update trip, choose travelers, upload and process attachments, review extracted facts, save confirmed bookings/transfers, load memory, make an initial plan, propose/review revisions, record feedback, and correct/delete memory. Follow current backend conventions for concrete route names and database technology. Ensure retries and duplicate upload/message delivery do not create duplicate bookings or plan items. Never allow an LLM-generated ID or client user ID to bypass server ownership checks.

## Decision logic for the next question

Implement an explicit next-step policy around known, unknown, proposed, and confirmed facts. A model can rank candidates, but deterministic application rules must enforce the priorities. A possible order:

1. If a user correction is pending, apply or confirm it and update the current view.
2. If an import contains consequential proposed facts, show a compact review before planning around them.
3. If destination or timing is missing, ask that one missing fact.
4. If the route to the destination is unknown and materially changes the plan, ask the travel mode.
5. If flying, ask about booked flights or offer upload/manual entry/search; once confirmed, derive actual first/last-day windows and transfers.
6. Ask about lodging, fixed commitments, or companions only as needed for a useful recommendation.
7. If enough is known, create a provisional or confirmed plan and ask for feedback, rather than continuing the intake.

Never ask for something already present in a confirmed import, trip record, prior conversation, or profile. When sources conflict, say what conflicts and ask one clarifying question. When a detail is uncertain but nonblocking, proceed with a labeled assumption and make it editable.

## Deliver in milestones, with an end-to-end vertical slice first

**First implementation target:** an authenticated returning traveler opens the redesigned “Your trip” screen, sees their preferred name if confirmed, sees an editable compact trip summary, answers “What have you already booked or decided?”, uploads or enters a flight/hotel, reviews proposed extracted facts, and gets the next relevant question. Pip plans both airport transfers around the actual arrival/departure windows and offers a light first-day plan. The traveler can say “too much walking,” receive a small proposed revision, accept or reject it, and return later without Pip asking the same questions again.

Then extend the vertical slice to new-user Getting to Know You, persistent memory, multilingual input and localization, additional attachments/voice, live location and operational context, and real-world pilot refinements. Test hands-free use on existing hardware only after the phone experience proves valuable. Custom Pip wearable hardware is a later gated product decision, outside this implementation.

## Acceptance scenarios

Run these through the app and backend, using repository tests and targeted manual checks as appropriate:

1. **Personalized returning traveler:** A confirmed preferred name appears naturally once; known destination/dates/hotel are shown compactly; Pip does not ask for them again. If preferred name is unknown, it does not guess.
2. **Unplanned New York trip:** “Next long weekend” is resolved or confirmed; “Nothing yet” advances without forcing a planning-state choice. Pip asks how they will get there and offers flight search if flying without a booking.
3. **Booked flight:** User uploads a flight confirmation; extraction is proposed, reviewed, and edited if needed. Pip uses actual arrival airport/time to suggest the hotel transfer, and covers home-to-departure-airport plus return legs. It does not fabricate a terminal or booked Uber.
4. **Partial plan:** A hotel and Saturday event stay fixed. Pip fills gaps without moving them and uses realistic transit and check-in buffers.
5. **Correction and memory:** “I usually love walking, just not today” changes today’s plan but does not create a permanent dislike or disability. “Don't remember that” removes the relevant memory.
6. **Different travelers:** Same destination/dates with different confirmed preferences and mobility constraints produce meaningfully different, modest plans. Sensitive traits are never inferred.
7. **Language continuity:** User changes conversation language; existing trip and memory remain intact, and localized UI remains readable.
8. **Ownership:** Authenticated user A cannot access user B’s trip, attachment, memory, or plan by swapping an ID.
9. **Unknown/live data:** Without configured real-time sources, Pip labels schedule/status/cost estimates; it never claims a live flight check or booking occurred.
10. **Small-screen accessibility:** The first screen is less crowded than the uploaded image, the main action is discoverable, controls work with keyboard/VoiceOver/dynamic text, and only one active question is visible.

## Final handoff

Report the files changed, the user-facing flow, backend/data changes, meaningful tests and results, any integration not yet configured, and the next smallest product experiment. Show screenshots or a short recording of the redesigned first screen and one conversation when the environment supports it. Be precise about what is implemented versus designed or stubbed. Preserve the user's existing project and avoid claiming the entire nine-milestone roadmap is complete after the first vertical slice.
