# Trips — milestones 2.4 and 2.5

Open **PipGoGo → Trips → Create trip**. Enter one or more destinations in travel order,
optionally choose start/end dates and accommodation, and select saved companions. Save returns
to the updated trip list. Open a trip to see its saved details. Details and companion names refresh automatically on
opening, returning to the foreground, and closing the editor. There is no manual refresh
button in trip details. Automatic reads preserve any unsaved draft. Refreshing a deleted trip removes it from the local list.

Only destinations are required. Dates use calendar-day `YYYY-MM-DD` values, independent of
UTC timestamp serialization. The form checks destination count/text limits, date ordering,
accommodation limits, and companion count before sending. Missing selected companions are
reported by the backend; refresh and remove the unavailable selection before trying again.

Trip creation uses the existing authenticated GET list/detail and PUT-by-UUID endpoints.
Every new draft keeps one UUID, version zero, and an immutable request/key for uncertain
retries. A replayed receipt cannot replace a newer trip already fetched during recovery.
A creation conflict never becomes an overwrite: the traveler can review the existing trip,
explicitly keep the draft under a new identity, or confirm discarding it in favor of saved state.
The complete current trip body is modeled, including fields not yet editable in this screen,
so later replacement writes can preserve flights, accommodation references, preferences,
budget, transportation, itinerary, and constraints.

Drafts survive navigation within the signed-in app session. The list offers **Continue trip draft**.
Sign-out cancels outstanding work, clears data/drafts, and prevents late responses from restoring
the previous account's trips. Uncertain requests freeze editing until retried. Draft/request
storage is memory-only; this milestone does not provide durable offline creation or sync.

## Verification — September 26, 2026

- **73 iOS tests passed:** 57 prior tests plus 15 trip model/state tests and one HTTP contract
  case. Coverage includes create/list/detail reload with companions, optional fields, a lost
  response after commit and exact retry, draft navigation, validation, calendar days, full-body
  round trips, missing companions, creation conflicts, deleted detail, stale receipt handling,
  list failures, and late list/save responses after sign-out.
- **6 backend regressions passed** for validation/ownership, retries/conflicts, and user
  isolation across memory and Moto-backed DynamoDB. No backend API or AWS infrastructure
  changes were needed.
- Signed Debug build passed and was installed on the connected iPhone 12. The LAN backend
  reported ready with Cognito and DynamoDB.
- Automated networking uses mocked responses. Physical-device acceptance below remains pending.

## Device acceptance

1. Open Trips and create a test trip with a destination, optional dates/accommodation, and a
   saved companion. A successful save should return to the list.
2. Open the trip and verify all entered details and selected companions. Leave and reopen it;
   restart the app while online and verify the saved record reloads.
3. Start another draft, navigate back, and use Continue new trip. Confirm the draft is kept.
4. In a controlled connection interruption, try saving. Keep the app open, reconnect, and retry;
   verify exactly one trip appears. Discard an unsaved draft separately and confirm it clears.
5. Sign out and switch accounts; the previous trip list/draft must not appear in the new account.

Trip editing and confirmed deletion are now implemented in **milestone 2.5**, described below.
Check-in/packages follow 2.6–2.7. AI-assisted trip creation remains planned for Step 3; see
backend `docs/ai-trip-planning.md`. Durable offline storage and automatic sync remain Step 4.

## Trip editing and deletion — milestone 2.5

Open a saved trip, then tap **Edit**. Change destinations, dates, accommodation (including its
reservation reference), selected companions, transportation plans, itinerary, constraints, or
trip preferences. Clearing an optional value and saving removes it. **Clear accommodation**
removes all lodging fields after Save. Existing flights, check-in timestamps, and exact monetary
budget values remain preserved; dedicated editors for those fields are not provided here.
The detailed trip view continues to show them.

Only one trip draft is open at a time. Back to trip/navigation preserves the draft; return through
Edit or **Continue trip draft**. Save completes only when the backend confirms the operation.
Discard requires confirmation. Failed validation leaves the draft editable. Uncertain saves or
deletions retain their exact body, UUID, key, and expected version, and freeze changes until retry.

A version conflict provides both draft and saved-trip review screens. **Keep my draft** updates
the baseline to the reviewed version without writing; a separate Save makes a new operation.
**Use existing trip** requires confirmation before discarding the draft and does not write.
If the trip was deleted elsewhere, the traveler may accept the removal or explicitly keep a
copy under a new UUID. The deleted trip itself cannot be resurrected.

**Delete trip** is available on an unchanged saved draft and requires confirmation. Save or
discard edits first. A deletion conflict requires reviewing the changed trip and a fresh delete
confirmation. A successful deletion removes the list/detail entry. Empty-body tombstone
responses are decoded separately from active trips. Known deletions prevent old save receipts
from restoring list rows. Historical packages, answers, and receipts remain until account
deletion; the UI explicitly distinguishes this from permanent erasure.

### Verification — September 26, 2026

- **85 iOS tests passed**: 73 prior plus 11 edit/delete state cases and one HTTP contract case.
  Tests exercise unedited-field preservation, versioned edits, navigation/draft retention,
  exact retries, explicit conflict resolution, tombstone handling, deletion recovery, removed
  records versus stale receipts, validation, and late deletion responses after sign-out.
- **10 backend regressions passed** across memory and Moto-backed DynamoDB for validation,
  conflicts/retries, ownership/isolation, tombstones, and companion-in-use protection.
- Signed Debug build passed and was installed on the connected iPhone 12; the LAN backend
  reported ready with Cognito and DynamoDB.
- These are automated/mocked checks; physical-device edit/conflict/delete acceptance remains
  pending. No backend API or CloudFormation changes were required.

### Device acceptance — pending

1. Open a test trip → Edit. Change its destination/dates, clear an optional field, and change
   companions or itinerary. Save, reopen, and verify the changes.
2. Leave an unsaved edit, then reopen it through Edit/Continue trip draft. Confirm the draft
   remains. Discard separately and verify the saved record remains unchanged.
3. While an edit is open, change the same trip from a second client. Save in the app; review
   both versions, keep the draft, and save explicitly. Verify the reviewed version is used.
4. Delete a disposable trip after confirmation. Verify it stays absent after refresh/relaunch.
   With a controlled connection interruption, retry the pending deletion after reconnecting.
5. Remove a companion from every active test trip; confirm that companion can then be deleted.

The next implementation milestone is **2.6 — pre-trip check-in**. Earlier physical-device
acceptance checks remain pending until observed; passing mocked tests does not complete them.
