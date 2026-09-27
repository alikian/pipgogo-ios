# Travel companions — milestone 2.3

Open **PipPipGo → Companions** to list, add, edit, or delete recurring travel companions.
After a successful save, the editor returns to the updated companion list. Failed saves and
conflicts keep the editor open with the draft intact.
Nickname, relationship, age range, and all preference fields are optional. An empty nickname
appears as “Unnamed companion.” Clearing fields and saving removes their saved values.

The shared authenticated API client uses GET `/v1/companions` and PUT/DELETE
`/v1/companions/{uuid}`. Each new companion receives a client UUID; creates send version zero.
Updates and deletions send the saved version. Each operation retains its UUID, body, version,
and idempotency key until its outcome is confirmed. A connection, server, or response-decoding
failure freezes the editor and exposes an explicit retry; a retry cannot silently create a
second companion or overwrite a newer version.

A session-owned editor preserves an unfinished draft when navigating back. Continue that draft,
save, or discard it before editing someone else. Refreshing the list does not replace the draft.
Sign-out clears the list, editor, and pending operation, cancels work, and prevents late responses
from restoring another account's data. Drafts and uncertain operations are memory-only: durable
storage and the offline outbox remain Step 4. The editor explains this limitation.

Version conflicts display both local and saved values. Keeping a draft updates its baseline but
does not write automatically; a separate Save creates a new operation. Using saved state asks
for confirmation before discarding the draft. If another device deleted the companion, keeping
the draft explicitly creates a new UUID; the deleted identity is never resurrected.

Deletion requires confirmation and no unsaved edits. A changed companion must be reviewed
before confirming deletion again. The backend's `companion_in_use` rejection explains that the
companion must first be removed from every active trip. Trip editing is now available from Trips → a saved trip → Edit.
Successful deletion removes the list row; the API retains a tombstone and historical packages
may still contain the companion's details. The UI does not promise permanent erasure.

## Verification — September 26, 2026

- 57 iOS tests passed: the previous 42 plus 13 companion state/model cases and two HTTP service
  cases. Coverage includes create/reload/edit/clear/delete, exact retries, version conflicts,
  tombstones, in-use rejection, draft preservation, validation, and a late write after reset.
- Backend companion-in-use regression passed twice: memory and Moto-backed DynamoDB. It checks
  rejection while linked to an active trip and successful deletion after that trip is removed.
- Signed Debug iPhone build passed and was installed on the connected iPhone 12. The local
  backend reported ready with Cognito/DynamoDB at the configured Mac LAN address.
- Automated iOS HTTP tests use mocked responses. They do not establish live Google/account or
  physical-device companion acceptance.

## Physical-device acceptance — pending

With the Mac backend running and the iPhone on the same LAN:

1. Sign in, open Companions, add a test companion with preferences, and save.
2. Return to the list, reopen the companion, change a value and clear another, then save.
   Reopen after an app restart to confirm the backend retained those changes.
3. Edit a draft and navigate back; Continue editing must restore it. In a controlled network
   interruption, retry an uncertain save after reconnecting and check no duplicate appears.
4. Delete the test companion after confirmation; verify it stays absent after refreshing.
5. Switch accounts and confirm the other account does not show the previous list or draft.

Concurrent-edit review and active-trip deletion rejection have automated coverage. Live checks
require a second client/current trip setup; the trip list and editing UI are now available. Keep the earlier
profile save/reopen/clear acceptance marked pending until actually confirmed.
