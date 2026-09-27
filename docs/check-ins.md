# Pre-trip check-in — milestone 2.6

Implemented September 26, 2026. Physical-device acceptance is pending.

Open **Trips → a saved trip → Pre-trip check-in**. Review the loaded destination,
dates and full trip details, add optional requests/concerns, explicitly confirm the
context, then save. Reopening loads the saved check-in. Clearing notes removes them
on the next successful save. Each field accepts up to 2,000 Unicode code points.

The confirmation names a trip version. A later trip change makes the old check-in
stale. Refresh, review and confirm again; the server also rejects a write that
confirms an outdated trip. Check-in record versions are separate from trip versions.

## Retry and conflict behavior

- Uncertain saves freeze the request body, idempotency key and expected check-in
  version. Retry sends that same operation, including after authentication refresh.
- Changed check-ins offer local/saved note comparison. Keeping local notes rebases
  against the reviewed check-in version; a separate confirmation and save is required.
  Using saved notes requires confirmation before replacing local edits.
- A successful retry may return an old receipt. The client reloads the check-in and
  trip before showing the confirmation as current. A failed reload blocks confirmation.
- Drafts survive navigation independently for each trip in the current session.
  Sign-out cancels work and clears drafts; late responses cannot restore them.
- Missing/deleted trips cannot be confirmed. Read failures retain local notes and
  block saves until current context can be loaded.

Live travel data remains **unavailable**. The screen shows missing data categories,
refresh-attempt time and provider warnings. Saving does not verify operational
information, create a booking, generate a package or provide durable offline storage.

## Physical-iPhone acceptance (pending)

Use the real Cognito/DynamoDB development backend and dedicated test records:

1. Open a saved trip, enter both notes, confirm and save. Navigate away and reopen;
   verify notes and confirmed version. Clear notes, save and reopen again.
2. Keep a local draft, navigate to another trip and return; verify both drafts stay
   separate. Confirm only after reviewing the displayed trip context.
3. Edit the trip after a successful check-in. Reopen check-in, verify it is stale,
   then reconfirm. Also edit the trip from another client after loading the screen:
   saving the stale context must fail and retain notes until refresh/reconfirmation.
4. Update the same check-in from another client. Verify local/saved comparison,
   deliberate resolution and separate save. Neither branch should overwrite silently.
5. Interrupt a save, retry, and verify one version increment. Test a receipt replay
   after a later trip edit; the app must not call the older confirmation current.
6. Sign out with an open draft and switch accounts; notes must not cross accounts.
   Recheck existing sign-in, refresh and logout separately.

Automated state/service tests and memory/Moto backend tests cover these contracts;
they do not constitute device or live concurrency acceptance. Appium setup and the
integrated physical-device journey remain milestone 2.8. Next feature: **2.7 — partial
companion package**.
