# Pip Traveler Intelligence — Getting to Know You & Adaptive Travel

Source: https://docs.google.com/document/d/164nFTLecPZiQzFRrEpG5t7EdcgccPwT7vpfgf5Kz29o/edit?tab=t.0

Snapshot retrieved 2026-09-27. Revision: `ANLCKQmm6wcom-vm_r7aeaOB2fNEIB3nqoLHP6Yd75I-dkOG-KnSqsmHfp7JfdsBLCSBgGiWiDicnV84T-MqHxKuOFXY53Vygxihv5jJabI`.

Pip Traveler Intelligence — Getting to Know You & Adaptive Travel

1. Purpose

Pip should not behave like a traditional travel questionnaire or itinerary generator.

Pip's goal is to get to know the traveler naturally, remember what matters, learn from their experiences, and continuously adapt the trip as they travel.

Core loop:

Get to know → Travel → Observe → Learn → Adapt → Remember

The desired progression:

First interaction: “Pip understands what I'm looking for.”

During the trip: “Pip is learning what I actually enjoy.”

Later in the trip: “Pip's suggestions are getting better.”

Next trip: “Pip already knows me.”

2. Pip's Personality

Pip is a small traveling duck who accompanies the traveler.

Pip is curious, calm, friendly, multilingual, observant, helpful without being intrusive, comfortable with spontaneity, concise when the traveler is busy, conversational when the traveler wants to talk, willing to change its mind, never judgmental, and never overwhelming.

Most important personality rule:

PIP NEVER OVERPLANS.

Knowing more about the traveler should produce better choices, not more choices.

3. Replace the Traditional Profile Questionnaire

Replace the existing traveler-preference questionnaire with a conversational “Getting to Know You” experience.

Do not begin onboarding with predefined categories such as Museums / Food / Shopping / Nature or Relaxed / Moderate / Fast. These force people to describe themselves using categories chosen by the application.

Instead, Pip should let travelers tell stories and describe themselves in their own words.

4. Getting-to-Know-You Conversation

Example introduction:

“Hi, I'm Pip. 🦆

I'll travel with you, help when you need me, and get to know what you like along the way.

Before I help plan this trip, I'd love to know a little about you.”

Opening question:

“Tell me about a trip, vacation, or even a day out that you really enjoyed. What made it good?”

Requirements:

• Allow voice response.

• Allow text response.

• Allow Skip.

• No required minimum response length.

5. Follow the Traveler's Story

Pip should not simply proceed to the next predefined question.

The AI should understand the answer and ask one natural follow-up when useful.

Example:

Traveler:

“I loved Italy. We wandered around little streets, stopped whenever something looked interesting, ate at little restaurants and didn't really have a schedule.”

Pip:

“Sounds like discovering things as you go is a big part of the fun for you. Do you usually prefer that over having most of the day planned?”

The follow-up must relate directly to what the traveler said.

6. Three Core Discovery Areas

Pip should normally explore approximately three areas during initial onboarding.

A. What creates a great experience?

“Tell me about a trip or day out you really enjoyed. What made it good?”

B. What makes travel less enjoyable?

“What's something that tends to make a trip less enjoyable for you?”

Do not show a predefined list unless the traveler asks for examples.

C. What naturally attracts the traveler?

“When you're somewhere new, what do you naturally find yourself wanting to do?”

Open-ended responses may reveal interests that predefined categories would never capture.

7. Stop Asking Questions

Pip should not attempt to completely understand someone during onboarding.

After roughly three meaningful exchanges, Pip should normally say:

“That's enough for me to get started. I'll learn more about you as we travel, and you can correct me anytime.”

Offer:

• Continue with my trip

• Keep talking

• Skip

Getting to know the traveler continues throughout the relationship.

8. Structured Traveler Memory

Behind the conversational experience, Pip should convert useful information into structured Traveler Memory.

Possible categories:

• travel_style

• interests

• dislikes

• food_preferences

• discovery_preferences

• pace

• planning_style

• transportation_preferences

• comfort_preferences

• budget_tendencies

• interaction_preferences

• positive_experiences

• negative_experiences

Each learned item should contain metadata such as:

{

  "preference": "spontaneous_exploration",

  "value": "high",

  "confidence": 0.78,

  "source": "onboarding_conversation",

  "status": "inferred",

  "created_at": "...",

  "updated_at": "..."

}

9. Different Types of Knowledge

Pip must distinguish among:

EXPLICIT FACT

The traveler directly states something. Store with high confidence when appropriate.

CONFIRMED PREFERENCE

Pip makes an inference and the traveler confirms it.

INFERRED PREFERENCE

A reasonable interpretation that the traveler has not confirmed. Store with lower confidence.

TEMPORARY CONTEXT

Something that applies to the current situation and should not automatically become a permanent preference.

Example:

“I'm exhausted today.”

Store current_energy = low.

Do not conclude traveler_prefers_low_activity = true.

Similarly:

“I don't want sushi tonight.”

Do not conclude the traveler dislikes Japanese food.

10. Safety-Critical and Sensitive Information

Some information must not be inferred from behavior or casual conversation.

Ask directly, when relevant, about:

• food allergies

• accessibility requirements the traveler wants considered

• mobility requirements

• preferred language

• communication requirements

Allow:

• None

• Add information

• Prefer not to answer

Never infer medical conditions, disabilities, allergies, or other sensitive characteristics from behavior.

11. Pip Learns During the Trip

Traveler intelligence does not end after onboarding.

Interactions can provide useful information, for example:

“That restaurant was amazing.”

“This neighborhood is exactly my kind of place.”

“That museum wasn't really worth it.”

“We're walking way too much.”

“Please stop scheduling so many things.”

“I love places like this.”

Pip should determine whether each statement represents temporary circumstances, feedback about a particular experience, or a potentially reusable preference.

12. Learning Must Change the Current Trip

CORE REQUIREMENT:

Pip must use what it learns to improve the remainder of the CURRENT trip, not only future trips.

Example:

The original itinerary contains another museum tomorrow.

Today the traveler says:

“The museum wasn't really my thing. I loved wandering through that neighborhood afterward.”

Pip may infer:

museum_interest ↓

neighborhood_exploration ↑

Pip should reconsider tomorrow's plan.

It might say:

“I had another museum in tomorrow's plan, but based on what you enjoyed today, I think you'd have more fun exploring the old market neighborhood. Want me to swap it?”

The traveler remains in control.

13. The Itinerary Is a Living Plan

Pip must never treat an itinerary as a fixed schedule.

Continuously consider:

Traveler Memory

+

Trip Preferences

+

Current Location

+

Current Time

+

Weather

+

Reservations

+

Transportation

+

Walking

+

Energy

+

Recent Experiences

+

Traveler Feedback

+

Newly Discovered Interests

Then reason:

“Given what I know now, is the existing plan still right for this traveler?”

Sometimes the existing plan remains appropriate. Sometimes Pip should suggest changing it.

14. Understand Why an Experience Worked

Positive feedback is valuable.

Traveler:

“That was one of my favorite things we've done.”

If Pip cannot tell why, it may ask one short follow-up such as:

“What did you like most—the food, the atmosphere, meeting people, or just wandering around?”

Do not ask if the reason is already apparent.

The objective is to understand characteristics of experiences the traveler enjoys, not merely remember specific attractions.

15. Learn Quietly

Pip should generally not say:

“I updated your preference profile.”

Learning should become visible through better recommendations.

Instead:

“There's a little neighborhood about ten minutes from here that I think you'd really like.”

The traveler should experience the intelligence rather than see the database.

16. Learn From Behavior Carefully

Pip may learn from repeated choices as well as conversation.

If Pip repeatedly offers a museum, market, and neighborhood and the traveler repeatedly chooses markets and neighborhoods, Pip may gradually increase confidence in those preferences.

However:

ONE REJECTED RECOMMENDATION IS NOT A DISLIKE.

The traveler may be tired, it may be too expensive, weather may be bad, or they may have already done something similar.

Behavioral inference should initially have relatively low confidence.

17. User Corrections Always Win

Travelers must be able to correct Pip naturally:

“You've got me wrong. I actually love museums.”

“That was just because I was tired.”

“Normally I love walking.”

“Don't remember that.”

“That's only for this trip.”

Pip should immediately update, downgrade, remove, or scope the relevant inference.

18. Persistent Memory vs. Trip Context

Permanent traveler tendencies must remain separate from trip-specific desires.

Traveler Memory:

“I generally don't like tightly scheduled vacations.”

Current Trip:

“For our Disney trip, I want everything planned.”

Current-trip preferences override general preferences for that trip without erasing the traveler's normal tendencies.

19. Never Overplan

As Pip learns more, personalization must not produce increasingly elaborate itineraries.

If Pip learns that someone enjoys spontaneous exploration, it might say:

“Let's make the market the main thing this morning. The surrounding neighborhood is worth wandering around, so I wouldn't schedule anything else until after lunch.”

Not:

9:00 Market

10:15 Temple

11:00 Coffee

11:45 Shopping

12:30 Restaurant

1:45 Museum

Personalization should reduce cognitive load, not increase it.

20. The Pip Learning Loop

The core intelligence loop is:

OBSERVE

↓

UNDERSTAND

↓

IS THIS TEMPORARY?

↓

REMEMBER WHEN APPROPRIATE

↓

ADAPT

↓

SUGGEST

↓

OBSERVE THE RESULT

↓

LEARN AGAIN

The product model is NOT:

Build itinerary → Follow itinerary

The product model is:

Understand → Suggest → Experience → Learn → Adapt

21. Relationship Over Multiple Trips

Persistent Traveler Memory should allow Pip to become significantly better over time.

On a future trip Pip might say:

“Last time you really enjoyed exploring food markets and neighborhoods without much of a schedule. Want me to keep this trip loose like that too?”

The traveler can confirm or correct Pip.

Past preferences should never be assumed to apply forever.

22. Success Criterion

Do not evaluate this feature by how many profile fields Pip fills.

Evaluate it by whether travelers eventually feel:

“Pip knows how I like to travel.”

The strongest tests are:

• Pip's recommendations become observably better during the same trip.

• Travelers notice the increasing personalization.

• Returning travelers value that Pip already understands them.

• Pip reduces rather than increases planning burden.

• Travelers retain control over changes to their plans.

CORE PRODUCT DIFFERENTIATOR

Pip doesn't just plan your trip.

Pip travels with you, learns what you like, and changes the journey as you go.

23. Authentication & Traveler Identity — Current Implementation

CURRENT STATE

Authentication is already implemented in the native iPhone application using Google authentication, and the AWS ECS backend is already deployed.

Do not rebuild or replace the existing authentication flow as part of the traveler-intelligence work unless the current implementation fails a security or product requirement.

CORE REQUIREMENT

Pip's persistent Traveler Memory, trips, conversations, imports, and learned preferences must always belong to a stable authenticated traveler identity.

Identity architecture:

Authenticated account → stable server-side user_id → Traveler Memory → Trips → Conversations → Learned Preferences

Use a stable server-side identity.

If the existing authentication architecture uses Amazon Cognito federation, use the Cognito sub as user_id.

If the current application validates Google identity directly, create/use a stable internal user_id mapped server-side to the verified Google subject identifier. Do not use email address as the database primary key.

Email addresses may change and should remain account attributes rather than record ownership identifiers.

After authentication:

• Load the traveler's persistent Traveler Memory.

• Load saved/recurring travel companions.

• Load current and previous trips as appropriate.

• Restore relevant learned preferences.

• Keep trip-specific context separate from persistent Traveler Memory.

• Allow the same traveler to access the correct data across supported devices.

Authentication should feel lightweight. After the initial successful sign-in, returning users should normally proceed directly into Pip.

NEW USER FLOW

Sign in

→ Create/select first trip

→ Basic Trip Intake

→ Getting-to-Know-You conversation

→ Initial Traveler Memory

→ Personalized plan

RETURNING USER FLOW

Session restored/sign in

→ Load Traveler Memory

→ Select/create trip

→ Trip Intake or resume active trip

→ Pip continues with existing knowledge

SECURITY & PRIVACY

• Enforce authorization on every backend request that reads or modifies user/trip data.

• A user must never be able to retrieve another user's Traveler Memory, trips, attachments, or conversations by changing a client-provided identifier.

• Derive record ownership server-side from the validated authentication identity.

• Encrypt sensitive traveler information in transit and at rest.

• Provide account-data deletion and memory controls as the product matures.

• Never expose authentication tokens or provider credentials in application logs.

• Uploaded documents/photos/audio must use the same ownership model as Trip Context and Traveler Memory.

PLATFORM LOGIN EXPANSION

Google authentication is the current required login path.

Support additional login providers, such as Sign in with Apple, when needed for iOS distribution/product requirements without changing the underlying internal user identity model.

Authentication exists to support continuity and trust, not to create friction. Pip should feel like the same companion each time the traveler returns.

24. Multilingual Application & Pip Communication

The Pip application is multilingual. Multilingual support is a core product requirement, not only a translation feature used during travel.

The traveler must be able to choose their preferred application and conversation language. Pip should communicate naturally in that language across onboarding, Getting to Know You, trip planning, live assistance, Traveler Memory interactions, settings, alerts, and general conversation.

Core requirements:

• Localize the application interface for supported languages.

• Allow the traveler to select and change their preferred language.

• When appropriate, detect the language the traveler is speaking or typing and respond naturally in that language.

• Support multilingual voice input and text input.

• Support multilingual text-to-speech and speech-to-text where the selected providers support the language.

• Keep the traveler's preferred communication language separate from the local language at the destination.

• A traveler may speak one language with Pip while Pip translates to or from a different local language.

• Preserve meaning and traveler preferences across languages rather than creating separate profiles for each language.

• Traveler Memory belongs to the person, not to a language. Changing languages must not reset what Pip knows about the traveler.

• User-generated profile information and memories should retain the original text when useful while also storing normalized meaning that can be used regardless of the current conversation language.

• Support switching languages during a conversation when practical.

• Do not assume nationality, home country, or cultural preferences based on the language selected.

Example:

The traveler uses Pip in Farsi while visiting Japan. Pip can converse with the traveler in Farsi, understand Japanese speech when translation is requested, and produce appropriate Japanese speech for a local person. The traveler's persistent preferences remain the same whether they later use Pip in English, Farsi, or another supported language.

Localization:

All user-facing application strings should be implemented through a localization system rather than hard-coded English text. Design layouts so translated strings can expand or contract without breaking the interface. Support right-to-left layout for languages such as Farsi and Arabic when those languages are enabled.

Pip's personality should remain consistent across languages: curious, calm, friendly, concise, observant, and never overplanning. Translation should preserve intent and tone rather than mechanically translating word-for-word.

The architecture should make it possible to add additional languages without redesigning the application.

25. Implementation Milestones — Rebaselined to Current Build

CURRENT BUILD BASELINE — ALREADY IMPLEMENTED

The following foundation already exists and should not be rebuilt unless a defect or security issue requires it:

• Native iPhone application.

• Google authentication.

• AWS ECS backend deployment.

• Authenticated app-to-backend communication.

Engineering rule:

Reuse the existing authentication and backend architecture. Do not spend the next milestone redesigning infrastructure that already works. The next work should prove Pip's traveler intelligence and trip experience.

MILESTONE 1 — TRIP & TRAVELER INTAKE FOUNDATION

Goal:

Create the minimum structured Trip Context Pip needs before generating a plan.

Build:

• Create Trip flow with destination and dates.

• Ask: “How much of this trip have you already planned?”

  - Mostly planned

  - Partly planned

  - Starting from scratch

• Allow existing plans to be entered manually or imported from supported photos/documents.

• Select saved travelers or add travelers for this trip.

• Capture optional trip-relevant needs and constraints.

• Capture transportation plan.

• Capture lodging.

• Capture fixed reservations/commitments.

• Keep imported facts separate from Pip-generated suggestions.

• Create trip lifecycle states such as draft, intake_in_progress, ready_to_plan, planned, active, completed.

Success test:

A user can create a trip and Pip has enough structured context to understand destination, timing, who is traveling, what is already booked, transportation, lodging, and important constraints.

MILESTONE 2 — GETTING TO KNOW YOU + TRAVELER MEMORY

Goal:

Replace the narrow preference questionnaire with the open-ended Pip conversation and persistent Traveler Memory.

Build:

• Pip introduction.

• Approximately three meaningful open-ended exchanges.

• Dynamic follow-ups based on what the traveler actually says.

• Explicit vs confirmed vs inferred vs temporary information.

• Confidence/source/timestamps.

• Persistent Traveler Memory tied to the authenticated traveler.

• User corrections and “don't remember that.”

• Trip-specific overrides that do not overwrite general Traveler Memory.

Success test:

Pip can explain in useful plain language what it has learned and use it on a later session without replaying the questionnaire.

MILESTONE 3 — PERSONALIZED INITIAL TRIP PLAN

Goal:

Prove that Traveler Memory + Trip Context produce a better plan than a generic itinerary generator.

Build:

• Generate a lightweight initial plan only after sufficient Trip Intake.

• Respect fixed reservations and imported commitments.

• Use Traveler Memory to influence pace, activity type, food, walking, planning density, and spontaneity.

• Support three planning behaviors:

  - Mostly planned: protect existing itinerary and help around it.

  - Partly planned: preserve fixed items and fill useful gaps.

  - Starting from scratch: propose a small number of anchor experiences with open time.

• Never fill every available hour by default.

• Clearly distinguish confirmed bookings from Pip suggestions.

• Let the traveler accept, reject, move, or remove suggestions.

Success test:

Two travelers going to the same destination can receive meaningfully different plans because their travelers, constraints, and preferences differ.

MILESTONE 4 — LEARN DURING THE TRIP + ADAPTIVE PLAN

Goal:

Make Pip improve the current trip as it learns.

Build:

• Capture explicit feedback such as “I loved this,” “too much walking,” “not my thing,” and “places like this are great.”

• Distinguish temporary state from reusable preference.

• Update Traveler Memory confidence appropriately.

• Re-evaluate future suggestions after meaningful feedback.

• Suggest changes rather than silently modifying fixed plans.

• Preserve reservations and important commitments.

• Allow one-tap accept/reject of proposed adjustments.

• Learn from repeated behavior cautiously.

Core loop:

Understand → Suggest → Experience → Learn → Adapt.

Success test:

After meaningful feedback, Pip proposes a better remainder of the current day or following day and can explain the reason briefly when asked.

MILESTONE 5 — MULTILINGUAL + MULTIMODAL EXPERIENCE

Goal:

Let travelers communicate with Pip naturally rather than through one rigid interface.

Build in practical order:

1. Text.

2. Photo upload.

3. Camera capture.

4. Voice recording.

5. PDF/DOCX upload.

6. Live voice conversation.

7. Additional localization/RTL refinement as needed.

Requirements:

• Traveler Memory must remain language-independent.

• Uploaded itinerary/reservation documents can feed Trip Intake after user confirmation.

• Multimodal inputs must share the same Trip Context and Traveler Memory.

Success test:

A traveler can show, tell, type, or send Pip something and continue the same coherent trip conversation.

MILESTONE 6 — LOCATION + LIVE TRAVEL CONTEXT

Goal:

Move Pip from planning app to active travel companion.

Build:

• GPS/location context with permission.

• Current time.

• Nearby places.

• Directions/transit where appropriate.

• Opening hours and operational information from reliable sources.

• Weather and relevant disruptions when useful.

• Context-aware questions such as:

  - “What should we do for the next two hours?”

  - “Where can we eat that's easy from here?”

  - “We're tired. What should we change?”

• Keep live facts separate from stable knowledge.

Success test:

The traveler can physically move through the San Diego test journey and Pip responds using real current context without the traveler repeatedly entering their location.

MILESTONE 7 — REAL-WORLD PILOT

Goal:

Determine whether the experience is valuable before expanding scope.

Test approximately 5–10 real travelers.

Measure:

• Did they naturally return to Pip?

• Did Pip learn useful preferences?

• Did plans improve during the trip?

• Did users accept adaptive changes?

• How often did they still open other apps?

• Did Pip reduce cognitive burden?

• Did users trust imported/extracted information?

• Would they deliberately use Pip on another trip?

Primary success question:

“Would I deliberately travel with Pip again?”

MILESTONE 8 — HANDS-FREE AUDIO USING EXISTING HARDWARE

Goal:

Test whether hands-free access materially improves the experience before custom manufacturing.

Test:

• Open-ear headphones.

• Bone-conduction headphones.

• Existing bone-conduction cap prototype.

• Bluetooth reliability.

• Microphone quality.

• Outdoor/wind performance.

• Battery usage.

• Comfort for several hours.

• Live multilingual conversation.

Success test:

Travelers clearly prefer having hands-free Pip available during real travel over repeatedly using the phone.

MILESTONE 9 — PURPOSE-BUILT PIP WEARABLE

Only begin if previous milestones demonstrate demand and a meaningful hands-free advantage.

Investigate:

• Pip cap / wearable audio hardware.

• Private traveler audio.

• Outward-facing translated audio when appropriate.

• Microphone array.

• Echo/feedback management.

• Bluetooth architecture.

• Battery/charging.

• Removable electronics.

• Washable textile.

• Industrial design.

• Regulatory requirements.

• Patent/freedom-to-operate review of the final architecture.

Success test:

The dedicated wearable creates enough additional value over ordinary consumer audio devices to justify manufacturing.

RELEASE DISCIPLINE

Do not move to the next layer because it is exciting. Each milestone should answer one product question:

1. Does Pip understand the trip we are actually taking?

2. Can Pip get to know and remember the traveler?

3. Does that knowledge materially improve the initial plan?

4. Does Pip learn and improve the current trip?

5. Can travelers interact naturally through multiple languages and input types?

6. Is Pip genuinely useful while moving through the real world?

7. Do real travelers want it again?

8. Does hands-free access materially improve it?

9. Is custom hardware justified?

The first product capability to prove is not the hat. It is:

“Pip understands my trip, gets to know me, and becomes a better companion as we travel.”

26. Multimodal Interaction With Pip

Pip should support multiple ways for the traveler to communicate, because travel situations vary. Sometimes typing is easiest, sometimes speaking is faster, and sometimes the traveler needs to show Pip what they are looking at.

The interaction experience should support the following input types:

A. Text

The traveler can type naturally to Pip.

Examples:

• “What should we do next?”

• “Find somewhere nearby that's easy and not crowded.”

• “Change tomorrow because we're tired.”

• “What does this sign mean?”

Text remains the most reliable fallback interaction method.

B. Photo Upload

The traveler can upload an existing photo from the device.

Pip should be able to use the photo together with the current conversation and trip context.

Examples:

• restaurant menu

• street sign

• transit map

• attraction information

• ticket

• receipt

• hotel instructions

• food item

• landmark

• product or souvenir

• screenshot

Possible tasks:

• translate visible text

• explain what the traveler is seeing

• identify useful travel information

• extract dates, times, addresses, reservation details, or instructions

• answer questions about the image

• use relevant information to assist with the current trip

Pip should not automatically store every uploaded photo permanently. Retention should follow privacy and product requirements.

C. Camera Capture

Allow the traveler to open the camera directly from the Pip conversation.

The traveler should be able to take a photo and immediately ask a question about it.

Examples:

• “What does this say?”

• “Which train do I take?”

• “What is this building?”

• “Can I eat this with my allergy?”

• “Where is the entrance?”

• “Translate this menu.”

Camera capture should minimize friction:

Open camera → capture → optionally add voice/text question → send to Pip.

Future versions may investigate live visual assistance, but the first implementation should use deliberate image capture rather than continuous camera streaming unless there is clear evidence that live video is necessary.

D. Voice Recording

Allow the traveler to record and send a voice message to Pip.

Voice recordings are useful when:

• walking

• carrying luggage

• typing is inconvenient

• the traveler wants to explain something in detail

• connectivity is intermittent and a short recorded message is easier than a live session

Flow:

Tap/hold record → speak → stop/send → speech is transcribed → Pip reasons over the transcript and trip context → Pip responds using text and/or speech.

Where practical, preserve the original audio temporarily for transcription/retry while avoiding unnecessary long-term storage.

E. Live Voice Conversation

Pip should support real-time conversational interaction in addition to recorded voice messages.

The traveler should be able to speak naturally, hear Pip respond, interrupt when necessary, and continue with follow-up questions without repeatedly tapping controls.

Requirements:

• low-friction start/stop

• real-time speech recognition

• text-to-speech responses

• interruption / barge-in support

• conversational follow-ups

• multilingual speech

• language switching when appropriate

• concise responses while the traveler is moving

• visible transcript when useful

• clear microphone/listening state

• user-controlled mute/end controls

Live conversation is especially important for the future hands-free wearable experience.

F. PDF and DOCX File Upload

Allow the traveler to attach travel-related PDF and DOCX files to a Pip conversation.

Examples:

• itinerary

• airline confirmation

• hotel booking

• tour voucher

• cruise itinerary

• travel-insurance document

• event ticket information

• transportation instructions

• travel guide

• conference agenda

• visa/travel instructions

• rental-car confirmation

Pip should be able to:

• read supported documents

• summarize them

• answer questions about them

• extract relevant trip information

• identify dates, times, locations, confirmation details, and instructions

• propose adding relevant information to Trip Context

Important:

Pip should NOT silently modify the trip profile based on uploaded files when the extracted information could materially affect the trip.

Example:

“I found a hotel check-in at 3:00 PM and the address 123 Example Street. Add these to this trip?”

The user confirms before important extracted details become structured trip data.

G. Combined Inputs

Pip should be able to reason across multiple input types in the same conversation.

Examples:

Photo + voice:

Traveler photographs a train map and asks:

“Which one gets us closest to our hotel?”

PDF + text:

Traveler uploads an itinerary and says:

“Make this less exhausting.”

Camera + live conversation:

Traveler photographs a menu and asks:

“What would you recommend based on what you know I like?”

Voice + Traveler Memory:

Traveler says:

“We loved that neighborhood yesterday. Find something with the same feeling.”

The system should combine:

Current message

+

Uploaded media/document

+

Traveler Memory

+

Trip Context

+

Current location/time when permitted

+

Relevant live data

H. Interaction Composer

The main Pip conversation screen should provide a simple multimodal composer.

Recommended controls:

• text field

• microphone

• camera

• photo/library attachment

• file attachment

• live conversation button

Do not crowd the interface. Less frequently used attachment options can be grouped behind a single + or attachment control.

The primary interaction should still feel like:

“Talk to Pip however is easiest right now.”

I. Input Processing Pipeline

Each input type should be normalized into a form that the reasoning layer can use.

Conceptual flow:

User Input

↓

Input-Type Handler

↓

Extraction / Transcription / Vision / Document Parsing

↓

Relevant Structured Facts

+

Original User Intent

↓

Traveler Memory + Trip Context + Current Context

↓

Pip Reasoning

↓

Response / Suggested Action

Do not require the main AI model to directly handle every raw media-processing task when a specialized speech, vision, OCR, or document parser is more reliable.

J. Trust, Privacy, and User Control

Photos, recordings, camera captures, documents, transcripts, and live conversations can contain sensitive travel and personal information.

Requirements:

• tell the traveler when microphone/camera access is active

• request platform permissions only when needed

• do not continuously record in the background without an explicit user-facing feature and permission

• minimize storage of raw audio/images when no longer required

• protect uploaded files and extracted data with the same authorization model as Traveler Memory

• never make another user's attachments accessible through client-controlled identifiers

• allow future deletion controls for uploaded media and documents

• do not use sensitive uploaded travel content for advertising targeting

• clearly distinguish temporary conversation attachments from information intentionally saved into Trip Context or Traveler Memory

K. Capability Rollout

Do not block early product testing until every input type is complete.

Suggested order:

1. Text

2. Photo upload

3. Camera capture

4. Voice recording

5. PDF/DOCX upload

6. Live voice conversation

7. Deeper hands-free integration with wearable hardware

Each new input type should improve a real traveler task rather than exist only as a technical feature.

Success Criterion

A traveler should be able to communicate with Pip using whichever input method is most natural for the situation, without having to think about which application feature or tool to open.

The desired feeling is:

“I can just show Pip, tell Pip, send Pip the document, or talk to Pip—and it understands what I need.”

27. Trip Intake, Existing Plans & Planning Flow

PURPOSE

Trip Intake happens after a trip is created and before Pip generates an itinerary. It collects only the information that materially changes planning.

The experience should feel conversational and progressive, not like a giant travel form.

A. CREATE THE TRIP

Ask:

“Where are we going?”

Minimum required fields:

• destination

• approximate or exact dates

Everything else may be added progressively.

B. ASK HOW MUCH IS ALREADY PLANNED

Ask:

“How much of this trip have you already planned?”

Options:

• Mostly planned

• Partly planned

• Starting from scratch

This selection changes Pip's planning behavior.

Mostly planned:

Protect the existing itinerary. Pip helps around fixed plans, solves gaps/problems, and suggests improvements only where useful.

Partly planned:

Preserve fixed commitments. Pip fills gaps and can suggest better sequencing.

Starting from scratch:

Pip creates a lightweight personalized plan with a small number of anchor experiences and generous open time.

C. IMPORT WHAT THE TRAVELER ALREADY HAS

Prompt:

“Already booked anything? You can send it to me.”

Allow:

• PDF

• DOCX

• screenshot/photo

• camera capture

• typed information

• pasted text

Useful imports include:

• flights

• hotel/lodging

• Airbnb instructions

• rental car

• train tickets

• tours

• restaurant reservations

• event tickets

• cruise itinerary

• conference/event schedule

• existing itinerary

Extraction rule:

Imported content is first parsed into PROPOSED structured facts.

Example:

“I found:

Hotel: Example Hotel

Check-in: Dec 21 at 3 PM

Address: ...

Add this to your trip?”

The traveler confirms or edits important extracted facts before they become authoritative Trip Context.

Store provenance for imported information:

• source attachment/input

• extracted value

• extraction confidence when available

• user confirmation status

• timestamp

D. WHO IS TRAVELING?

Ask:

“Who's coming on this trip?”

Allow:

• select saved travelers

• add a new traveler

• traveling alone

For each traveler, collect only what materially affects the trip.

Useful information may include:

• name/nickname (optional)

• relationship (optional)

• age or age range when useful

• preferred language

• trip-specific interests

• relevant dietary needs

• relevant accessibility/mobility/sensory needs

Do not make assumptions from age alone.

A young child, older adult, or teenager may affect planning, but Pip should ask about practical needs rather than stereotype the person.

E. ACCESSIBILITY, MOBILITY & GROUP NEEDS

Ask in neutral optional language:

“Anything you'd like Pip to take into account for anyone on this trip?”

Possible user-provided considerations:

• wheelchair/accessibility

• limited walking

• stroller

• frequent rest breaks

• sensory considerations

• dietary restrictions/allergies

• small-child nap/rest needs

• older traveler comfort needs

• luggage burden

• other practical constraints

Always allow:

• None

• Add details

• Prefer not to answer

Do not infer disabilities, medical conditions, allergies, or other sensitive information.

F. TRANSPORTATION

Ask:

“How are you planning to get around?”

Options may include:

• own car

• rental car

• public transit

• train

• taxi/rideshare

• walking

• bicycle

• cruise/ship

• mixed

• not sure yet

Branch only when useful.

Examples:

Rental car → “Already reserved?”

Own car → relevant parking/road considerations.

Public transit → optimize around stations/transfers.

Not sure → Pip can help compare options later.

Transportation choice is Trip Context, not necessarily a permanent Traveler Memory preference.

G. LODGING

Ask:

“Where are you staying?”

Allow:

• import reservation

• type property/address

• photo/screenshot

• “I haven't booked yet”

Structured lodging fields may include:

• property name

• address

• check-in date/time

• check-out date/time

• confirmation reference

• parking information

• host/property instructions

• relevant access notes

H. FIXED COMMITMENTS

Ask:

“Anything already booked that I should protect?”

Examples:

• flights

• trains

• tours

• restaurant reservations

• weddings

• conferences

• theme park tickets

• sports/events

• appointments

Fixed commitments must be clearly marked and must not be silently moved or removed by Pip.

I. OPTIONAL TRIP CONSTRAINTS

Ask only when useful:

• trip budget / spending comfort

• must-do experiences

• things to avoid

• desired cities/regions

• luggage situation

• special arrival/departure concerns

Do not require users to fully configure these before proceeding.

J. GETTING TO KNOW YOU

For a new traveler, run the short open-ended Getting to Know You conversation before generating the first personalized plan.

For a returning traveler with useful Traveler Memory:

• do not replay onboarding

• briefly confirm major assumptions only when relevant

• allow trip-specific overrides

K. READY TO PLAN RULE

A trip becomes ready_to_plan when Pip has enough information to make a useful recommendation.

Minimum:

• destination

• dates or approximate duration

Strongly preferred when relevant:

• travelers

• fixed commitments

• lodging/arrival context

• transportation intent

• critical accessibility/dietary constraints the user chooses to provide

Do not block planning simply because optional fields are missing. Pip can ask later when the answer materially changes the plan.

L. PLANNING RULES

Before generating or revising a plan, Pip should combine:

Traveler Memory

+

Current Trip Context

+

Selected Travelers

+

Confirmed Imported Plans

+

Fixed Commitments

+

Transportation

+

Lodging

+

User-provided Needs/Constraints

+

Current Context / Live Data when relevant

Planner rules:

• Fixed commitments outrank suggestions.

• Trip-specific preferences outrank general Traveler Memory.

• Confirmed facts outrank inferred facts.

• Missing information should not be invented.

• Ask a follow-up only if the missing answer materially affects the plan.

• Prefer one or two meaningful anchor experiences over dense schedules.

• Cluster activities geographically when useful.

• Minimize unnecessary backtracking/transfers.

• Leave open time when that matches the traveler.

• Clearly label suggestions vs confirmed bookings.

• Never silently make or cancel a reservation.

28. Coding Readiness — Required Domain Model & Behaviors

The exact database technology and endpoint naming should follow the existing ECS backend conventions. The following are logical contracts Codex must support.

A. CORE ENTITIES

User / Authenticated Traveler

• user_id — stable server-side authenticated identity

• preferred_language

• locale

• created_at

• updated_at

TravelerMemoryItem

• memory_id

• user_id

• category

• key

• value

• confidence

• status: explicit | confirmed | inferred

• source_type

• source_reference (optional)

• scope: persistent | trip_specific

• created_at

• updated_at

Trip

• trip_id

• owner_user_id

• destination

• start_date

• end_date

• planning_state: mostly_planned | partly_planned | starting_from_scratch

• status: draft | intake_in_progress | ready_to_plan | planned | active | completed

• preferred_language_override (optional)

• notes

• created_at

• updated_at

TripTraveler

• trip_traveler_id

• trip_id

• linked_saved_traveler_id (optional)

• display_name (optional)

• relationship (optional)

• age_or_range (optional)

• preferred_language (optional)

• trip_specific_preferences (optional)

• user_confirmed_needs (optional)

TransportationPlan

• trip_id

• modes[]

• primary_mode (optional)

• rental_reserved (optional)

• own_vehicle (optional)

• details/notes

Accommodation

• accommodation_id

• trip_id

• property_name

• address

• check_in

• check_out

• confirmation_reference (optional)

• instructions (optional)

• source_reference (optional)

• confirmation_status

Commitment

• commitment_id

• trip_id

• type

• title

• start/end time

• location

• fixed: true/false

• confirmation_reference (optional)

• source_reference (optional)

• user_confirmed

AttachmentImport

• attachment_id

• trip_id

• type

• storage_reference

• processing_status

• extracted_facts[]

• user_confirmed_facts[]

• created_at

PlanItem

• plan_item_id

• trip_id

• date/time window

• title

• location

• item_type

• source: imported | confirmed_booking | pip_suggestion

• fixed

• status: proposed | accepted | rejected | completed | skipped

• rationale (optional)

• created_at

• updated_at

TripFeedback

• feedback_id

• trip_id

• plan_item_id (optional)

• raw_user_feedback

• interpreted_signal

• temporary_context flag

• proposed_memory_update (optional)

• created_at

B. REQUIRED BACKEND CAPABILITIES

The backend must support:

• create/read/update a trip owned by the authenticated user

• add/select travelers

• save trip constraints without turning them into global memory

• upload an attachment for a trip

• extract proposed structured facts from an attachment

• confirm/edit/reject extracted facts

• create/update accommodation, transportation, and commitments

• load Traveler Memory relevant to the trip

• create an initial personalized plan

• revise a plan while preserving fixed commitments

• record traveler feedback

• propose/update Traveler Memory based on feedback

• enforce ownership/authorization on every object

Do not trust user_id supplied by the client when authorizing data access. Resolve identity server-side from the validated authentication session/token.

C. PLANNER INPUT CONTRACT

The planning service should receive a normalized context object containing at minimum:

{

  authenticated_user,

  traveler_memory,

  trip,

  trip_travelers,

  accommodations,

  transportation,

  fixed_commitments,

  confirmed_imported_facts,

  trip_specific_constraints,

  existing_plan,

  current_context_if_available

}

The planner should return structured plan items plus a short user-facing explanation, not only free-form prose.

D. PLAN REVISION CONTRACT

When Pip learns something or conditions change, revision should receive:

• existing plan

• immutable/fixed items

• new traveler feedback

• updated temporary context

• relevant Traveler Memory

• current live context when available

Revision output should identify:

• items unchanged

• suggested moves/removals/additions

• reason for each material change

• whether user confirmation is required

Important:

Pip may suggest changing plans but must not silently alter fixed bookings or commitments.

E. IMPORT REVIEW CONTRACT

Document/image extraction must be two-stage:

1. Extract proposed facts.

2. User reviews/accepts/edits/rejects important facts.

Only confirmed facts become authoritative Trip Context for consequential planning.

F. MEMORY UPDATE CONTRACT

Memory updates must preserve:

• what the user explicitly said

• what Pip inferred

• confidence

• whether the information is temporary

• source

• trip scope vs persistent scope

Never convert a temporary statement into a persistent preference automatically.

G. FIRST END-TO-END CODING ACCEPTANCE TEST

The first implementation is ready for testing when this scenario works:

1. Existing authenticated iPhone user opens the app.

2. Creates a 4-day San Diego trip.

3. Selects “Partly planned.”

4. Uploads a hotel confirmation and an itinerary screenshot/document.

5. Pip extracts proposed lodging/reservation details.

6. User confirms or edits those details.

7. User selects who is traveling and provides any relevant group needs.

8. User selects rental car/public transit/other transportation.

9. New user completes the short Getting to Know You conversation, or returning user loads existing Traveler Memory.

10. Pip creates a lightweight personalized plan that preserves confirmed commitments.

11. User says something like “That's too much walking.”

12. Pip treats that as current feedback, adjusts the plan appropriately, and does not automatically turn it into a permanent disability or global preference.

13. User can accept/reject the proposed change.

14. All data remains associated only with the authenticated user and trip.

If this scenario works reliably, the core Pip traveler-intelligence system is ready for real-world pilot refinement.

## 29. Door-to-door journey (outbound and return)

User-supplied requirement added September 27, 2026 in chat, after the Google Doc snapshot above.
This addition is authoritative. Status: implemented in source September 27; deployment and
physical-device acceptance are tracked separately in the roadmap.

Ask naturally: “How will you get there—fly, drive, train, or something else?” If flying, ask
“Do you already have your flights?” Offer **Upload flight confirmation**, **Enter flight details**,
or **Find flights**. If flights aren’t booked, offer a link to an external flight search with the
trip details filled in where possible. The traveler can add the booking later.

For booked flights, capture each outbound, connecting, and return flight: airline, flight number,
airports, dates, local departure and arrival times, time zones, terminals when known, booking
reference, and status. Let the traveler review and correct extracted details before saving them.

Plan the ground transportation for each part of the trip: **home → departure airport → arrival
airport → hotel**, then the reverse for the return trip. Ask what’s already arranged and suggest
options such as Uber or another rideshare, a drop-off, parking, shuttle, transit, taxi, or rental
car. Include pickup points, luggage needs, travel time, and realistic airport buffers.

For a San Diego → New York trip, Pip should use the *actual* arrival airport and landing time
to plan the hotel transfer. JFK, LGA, and EWR call for different routes.

Flight and transfer times determine how much of the first and last days is available. Pip should
account for time zones, baggage, hotel check-in and check-out, and rest. If a flight changes, it
should recalculate affected transfers and activities while protecting confirmed reservations.

Keep the first trip screen light: **destination, when, and “Anything already decided?”** Ask
about flights and transfers progressively. If details are unknown, show a clearly provisional plan.

### Acceptance criteria

- The initial screen asks only for destination, timing and “Anything already decided?”;
  transportation, flight booking and transfer questions follow progressively.
- Flying offers all three entry paths. External search pre-fills known trip details where
  supported; opening a search never marks a flight as booked. Bookings can be added later.
- Upload and manual entry support every outbound, connecting and return segment and the fields
  above. Extracted details remain proposed until reviewed, corrected and confirmed.
- The journey covers outbound and return ground legs, distinguishing already-arranged transfers
  from suggestions, with pickup points, luggage, time estimates and airport buffers.
- San Diego → New York examples use the actual JFK, LGA or EWR arrival and local landing time;
  an unknown airport/time is visibly provisional rather than silently assumed.
- First/last-day availability accounts for time-zone and date changes, baggage, transfers,
  check-in/check-out and rest. Overnight and connecting flights preserve correct chronology.
- A changed flight triggers a reviewable update of affected transfers/activities. Confirmed
  reservations remain intact; conflicts are surfaced for the traveler’s decision.
- Estimated transfer durations and buffers are labeled; unavailable live flight/transport data
  is not presented as verified. Existing ownership, versioning and retry guarantees still apply.

## 30. Short, personal trip-intake conversation

User-supplied September 27, 2026. The “Your trip” screen uses a single heading, compact editable
summary, one active question and a visible Continue button. Greet by confirmed preferred name
when available (sparingly); never guess one. Reuse destination, timing, duration and reviewed
bookings. Ask for confirmation of ambiguous “next long weekend” dates rather than assuming a
holiday or asking for the same trip information again.

Remove the large introductory card and “How much is already planned?” list. Ask “What's already
decided?” and accept typed/speech input or uploads, with a quiet “Nothing yet” choice. Acknowledge
the answer and ask only the next useful question. Missing travel mode can offer “I have flights,”
“Help me find flights” and other modes. Reveal transfer details later; do not present lodging,
preferences and transport questionnaires together. Infer planning readiness from the conversation.

Implementation: short intake screen, explicit name-memory gate, date confirmation, speech
permission/cancellation flow, upload review and server `intake` action are implemented in source.
Physical-device speech, keyboard/layout, date and complete conversation acceptance remain pending.

## 31. Master implementation prompt — September 27, 2026

Use the [master implementation prompt](master-implementation-prompt.md) for the next usable
vertical slice. The live source document was rechecked September 28 UTC (modified September 27
23:40:33 UTC). Section 27 agrees with progressive intake and internal inferred readiness.
Persist conversation progress; apply deterministic next-step priorities; review imports before
planning; offer a provisional plan without a long questionnaire; show explicit revision changes.
Implementation and acceptance boundaries: [conversation slice](conversation-slice.md).
