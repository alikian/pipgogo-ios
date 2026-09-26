# Traveler profile — milestone 2.2

The account screen now links to **Traveler profile**. The editor supports optional nickname, home base, age range, usual travel party, languages, interests, dietary/accessibility needs, transportation preferences, pace and budget comfort. Lists use one entry per line. Removing optional values and saving clears them through the backend's replacement PUT contract.

## Behavior

- Initial GET 404 `not_found` opens an empty optional profile. Other load failures show Retry and prevent saving an unloaded profile.
- `ProfileStore` is owned by the signed-in session. Back navigation preserves unsaved drafts; load is not repeated over a draft. Sign-out resets profile data and cancels in-flight work. Generation checks prevent a late response from restoring a previous session's profile.
- Save freezes the body, idempotency key and expected version. While a result is uncertain, the editor keeps the draft and exact request, blocks edits/discard, and offers Retry save. A definite 400/422 rejection releases the request so the draft can be corrected.
- Version conflict shows all local and server fields side by side. **Keep my draft** adopts the reviewed server version but does not send a request; the user must review and Save, creating a new key. **Use saved profile** requires confirmation before replacing the local draft. No background overwrite or automatic merge occurs.
- Saved values replace the baseline only after success. Discard changes requires confirmation. Empty values and lists are normalized before encoding; per-entry 300-character and per-list 30-entry limits are validated locally.
- Drafts and pending requests are in memory, not a durable offline queue. The screen explains that sign-out or fully closing the app clears unsaved work. Durable offline persistence remains Step 4.

## Verification

All **42 iOS tests passed**: the prior 29 tests plus 11 profile model/store tests and two service/HTTP contract tests. Cases cover empty profile, all preferences, versioned edits, clearing fields, uncertain-save retries, explicit conflict choices, rejected saves, initial load failure, input limits, navigation preserving drafts, late responses after reset, backend nulls and interpreting only a true missing-profile response as empty.

The physical iPhone save/reopen/edit/clear acceptance check is pending confirmation. Simulated conflicts and failure cases are covered by tests; no live conflict was injected into the user's profile. Device build/install outcome is tracked in AGENTS.md.

## Device acceptance

1. Sign in if needed and open Traveler profile from the account screen.
2. Save a nickname and a preference. Navigate back and reopen; confirm values remain.
3. Fully close and reopen the app, then return to Traveler profile to prove the values reload from the backend.
4. Edit a value, clear an optional field/preference, save, and reopen again to confirm the cleared value stays empty.
5. Leave an unsaved change, go back and reopen the editor; the draft should still be there. Discard changes should restore the last saved values.

Use only values you want stored in the development account. No account/profile content is logged by the app.
