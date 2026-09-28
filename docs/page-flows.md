# PipPipGo — page flows and functions

Interactive offline atlas: [page-flows.html](page-flows.html). Based on current iOS source; introduction update is awaiting Dev deployment.

## 00. App overview

The whole experience: authenticate, get to know the traveler, then plan and adapt a trip.

```mermaid
flowchart TD
  entry["Open PipPipGo"] --> screen["App overview"]
  screen --> action0["No session"]
  action0 --> result0["Welcome / sign in"]
  screen --> action1["New traveler"]
  action1 --> result1["Home → Getting to know you"]
  screen --> action2["Returning traveler"]
  action2 --> result2["Home → Your trip → Talk / Plan"]
```

Identity is shared across trips; traveler memory is separate from trip context.

## 01. Welcome / sign in

Start Google sign-in without collecting credentials inside Pip.

```mermaid
flowchart TD
  entry["No valid saved session"] --> screen["Welcome / sign in"]
  screen --> action0["Continue with Google"]
  action0 --> result0["Google / Cognito → Account loading"]
  screen --> action1["Cancel or sign-in error"]
  action1 --> result1["Stay on Welcome; retry"]
```

PKCE, secure callback, Keychain session; no trip is created.

## 02. Account loading

Restore or validate the session and load the owned account.

```mermaid
flowchart TD
  entry["Sign-in callback or restored session"] --> screen["Account loading"]
  screen --> action0["Account loads"]
  action0 --> result0["Home"]
  screen --> action1["Account request fails"]
  action1 --> result1["Account unavailable"]
```

Authenticated GET /v1/me; refresh uses the existing auth client.

## 03. Account unavailable

Explain account loading failure without silently discarding the session.

```mermaid
flowchart TD
  entry["Account loading failed"] --> screen["Account unavailable"]
  screen --> action0["Try again"]
  action0 --> result0["Account loading"]
  screen --> action1["Sign out"]
  action1 --> result1["Welcome / sign in"]
```

Only the account request is retried; sign-out clears local session state.

## 04. Home

Greet by confirmed preferred name and show the appropriate starting point plus saved trips.

```mermaid
flowchart TD
  entry["Account loaded"] --> screen["Home"]
  screen --> action0["New traveler: tell Pip"]
  action0 --> result0["Getting to know you"]
  screen --> action1["Returning or skip for now"]
  action1 --> result1["Destination and timing"]
  screen --> action2["Open saved trip"]
  action2 --> result2["Talk to Pip"]
```

Loads journeys, traveler memory, saved travelers and introduction completion. Menu opens memory, language or sign-out.

## 05. Getting to know you

Optional story-led conversation about the person before creating a trip.

```mermaid
flowchart TD
  entry["New-traveler Home or Get to know me menu"] --> screen["Getting to know you"]
  screen --> action0["Type / speak, Continue"]
  action0 --> result0["One relevant personal follow-up"]
  screen --> action1["About three exchanges"]
  action1 --> result1["Continue with my trip / Keep talking"]
  screen --> action2["Skip for now"]
  action2 --> result2["Destination and timing"]
```

GET/PUT /v1/traveler-conversation. Saves owned messages/completion; no phantom trip. Inferred memories require review.

## 06. Destination and timing

Collect or edit the minimum trip context without repeating known information.

```mermaid
flowchart TD
  entry["New trip or summary Edit"] --> screen["Destination and timing"]
  screen --> action0["Destination + when"]
  action0 --> result0["Done → Your trip"]
  screen --> action1["Ambiguous long weekend"]
  action1 --> result1["Review concrete dates → confirm"]
  screen --> action2["Close / cancel"]
  action2 --> result2["Return with in-memory draft"]
```

Edits the client draft. API save occurs on the next deliberate trip action. Exact or approximate timing is supported.

## 07. Your trip

One compact summary, one active question, one answer area and a visible next action.

```mermaid
flowchart TD
  entry["Destination/timing set or Continue planning"] --> screen["Your trip"]
  screen --> action0["Answer / Nothing yet / skip"]
  action0 --> result0["Saved answer → next useful question"]
  screen --> action1["Upload / review booking"]
  action1 --> result1["Send it to Pip → Review before adding"]
  screen --> action2["Enough known / provisional plan"]
  action2 --> result2["Our plan"]
```

Versioned PUT journey and intake/skip actions. Reopens saved progress; no visible planning-state questionnaire.

## 08. Talk to Pip

One trip conversation that uses known facts and accepts corrections or feedback.

```mermaid
flowchart TD
  entry["Saved trip selected"] --> screen["Talk to Pip"]
  screen --> action0["Send message"]
  action0 --> result0["Reply / relevant follow-up"]
  screen --> action1["Feedback after accepted plan"]
  action1 --> result1["Proposed revision; accepted plan stays"]
  screen --> action2["Choose Plan or Details tab"]
  action2 --> result2["Our plan / Trip details"]
```

Owned conversation and scoped memory; temporary feedback remains separate. Attachments go through review.

## 09. Our plan

Show fixed bookings, transfer windows and optional suggestions separately.

```mermaid
flowchart TD
  entry["Plan tab or generated proposal"] --> screen["Our plan"]
  screen --> action0["Accept changes"]
  action0 --> result0["Replace suggestions; protect bookings"]
  screen --> action1["Keep current plan"]
  action1 --> result1["Reject proposal; keep accepted plan"]
  screen --> action2["Send feedback"]
  action2 --> result2["Revision diff or clarification"]
```

Explicit accept/reject actions. Changes list stays/adds/changes/removes. Empty clarification never clears the plan.

## 10. Trip details

Review known trip facts and enter focused editors only when needed.

```mermaid
flowchart TD
  entry["Details tab"] --> screen["Trip details"]
  screen --> action0["Edit summary"]
  action0 --> result0["Your trip → Destination and timing"]
  screen --> action1["Travel / people / reservations"]
  action1 --> result1["Door to door / Traveling together"]
  screen --> action2["Import existing plans"]
  action2 --> result2["Send it to Pip"]
```

Displays current context, timing and import status. It is separate from the light first screen.

## 11. Send it to Pip

Attach travel material or paste booking text for extraction.

```mermaid
flowchart TD
  entry["Upload / attachment control"] --> screen["Send it to Pip"]
  screen --> action0["PDF / DOCX / photo / text"]
  action0 --> result0["Extract proposed facts"]
  screen --> action1["Extraction succeeds"]
  action1 --> result1["Return to parent; review offered"]
  screen --> action2["Error or unsupported file"]
  action2 --> result2["Keep input; retry or replace"]
```

PUT journey imports. Raw file bytes are processed server-side; extracted facts are not yet authoritative. Camera/live voice are not implemented here.

## 12. Review before adding

Let the traveler correct or reject extracted facts before planning uses them.

```mermaid
flowchart TD
  entry["Proposed import"] --> screen["Review before adding"]
  screen --> action0["Edit / remove details"]
  action0 --> result0["Review corrected draft"]
  screen --> action1["Confirm retained details"]
  action1 --> result1["Save confirmed facts → parent screen"]
  screen --> action2["Remove all and confirm"]
  action2 --> result2["Reject import → parent screen"]
```

review_import is versioned and retry-safe. Only reviewed flights enter authoritative door-to-door context.

## 13. Door to door

Progressively capture how the traveler reaches the destination, flights and arranged transfers.

```mermaid
flowchart TD
  entry["Travel question or Flights and transfers"] --> screen["Door to door"]
  screen --> action0["Booked travel"]
  action0 --> result0["Upload or enter flight segments"]
  screen --> action1["Not booked"]
  action1 --> result1["External flight search; add later"]
  screen --> action2["Next: airport transfers"]
  action2 --> result2["Four legs → save / update suggestions"]
```

Actual airports and local times drive provisional windows. No live status, price, pickup verification or automatic booking.

## 14. Traveling together

Choose this trip’s travelers and optional needs without inferring sensitive traits.

```mermaid
flowchart TD
  entry["Travelers and reservations"] --> screen["Traveling together"]
  screen --> action0["Use saved traveler"]
  action0 --> result0["Add to this trip"]
  screen --> action1["Add person / optional needs"]
  action1 --> result1["Trip-only details or save traveler"]
  screen --> action2["Continue"]
  action2 --> result2["Make room for what matters"]
```

Saved traveler identity is distinct from trip-specific people/needs. Existing validation and ownership apply.

## 15. Make room for what matters

Capture lodging, fixed commitments and constraints that should shape the plan.

```mermaid
flowchart TD
  entry["Continue from Traveling together"] --> screen["Make room for what matters"]
  screen --> action0["Lodging and reservations"]
  action0 --> result0["Edit confirmed trip context"]
  screen --> action1["Constraints / notes"]
  action1 --> result1["Keep optional or unknown"]
  screen --> action2["Save trip context"]
  action2 --> result2["Return to Trip details"]
```

Replacement writes preserve supported trip fields; uncertain writes keep their original identity for retry.

## 16. What Pip remembers

View, correct or forget reusable knowledge, and edit the preferred name.

```mermaid
flowchart TD
  entry["Home menu or proposed memory"] --> screen["What Pip remembers"]
  screen --> action0["Save preferred name"]
  action0 --> result0["Update home and trip greetings"]
  screen --> action1["Remember / correct / scope"]
  action1 --> result1["Save explicit or confirmed memory"]
  screen --> action2["Forget and confirm"]
  action2 --> result2["Remove active memory"]
```

Memory uses authenticated ownership, versioning and source/scope metadata. Trip-specific context does not erase general preferences.

## 17. Language

Choose the application language while retaining trips and memories.

```mermaid
flowchart TD
  entry["Home language menu"] --> screen["Language"]
  screen --> action0["English"]
  action0 --> result0["Localized English UI"]
  screen --> action1["Farsi"]
  action1 --> result1["Localized Farsi UI and RTL"]
  screen --> action2["Dismiss"]
  action2 --> result2["Return to previous screen"]
```

App language is stored locally; each trip also has its own conversation language. Live language-switch acceptance remains pending.

## 18. Retry and conflict recovery

Recover from failures without losing drafts, duplicating writes or silently overwriting newer data.

```mermaid
flowchart TD
  entry["Inline error on any editing page"] --> screen["Retry and conflict recovery"]
  screen --> action0["Uncertain outcome"]
  action0 --> result0["Retry same body, key and version"]
  screen --> action1["Version conflict"]
  action1 --> result1["Review saved state; deliberate choice"]
  screen --> action2["Review required / validation"]
  action2 --> result2["Correct prerequisite; new deliberate action"]
```

Shared recovery component, not a separate navigation page. Account changes clear owned drafts and ignore late responses.
