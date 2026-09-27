# Shared API client — milestone 2.1

Completed September 25, 2026. This milestone provides transport, records and error handling; profile/trip screens and a durable offline outbox are later milestones.

## Construct once, retry the same operation

`APIEndpoint` restricts requests to the backend's known routes. Companion/trip IDs are caller-owned UUIDs: generate one when beginning creation and keep it for every retry. A mutation request captures encoded bytes, route, method, idempotency key and expected version once. Keep the request alongside the draft until its outcome is known.

```swift
let tripID = UUID() // retain with this draft
let operation = try APIRequest<APIRecord<JSONValue>>.put(
    .trip(tripID),
    body: JSONValue.object(["destinations": .array([.string("San Diego")])]),
    expectedVersion: 0
)
let saved = try await client.send(operation, using: authentication)
// On a timeout, retry `operation`, not a freshly constructed request.
```

Typed Codable body models can replace JSONValue in feature milestones. Encode backend field names explicitly with CodingKeys; do not send the whole record envelope as the editable body. PUT is replacement: optional fields omitted or explicitly null clear values according to the backend contract. Keep other supported fields intact while editing. `APIJSON.encoder()` freezes sorted-key JSON; timestamps encode ISO 8601 and dates-only fields should use the API's date-only representation.

`put` requires a nonnegative expected version (zero creates). `delete` requires a positive version. `post` is limited to questions/package generation and includes a retry key without a version header. Trips/companions must be created with PUT. `deleteAccount()` follows the server's separate idempotent account-deletion contract and intentionally omits key/version headers.

## Authentication and retries

`AuthenticationService` implements `AccessTokenProviding`. The shared client obtains a usable token, sends the operation, and on HTTP 401 forces refresh once before resending the exact frozen operation. A second 401 escapes to the caller. Token-refresh failures propagate. Cancellation is preserved.

There is no automatic retry for transport failures, 409, 429 or server errors. A failed connection can have an unknown write outcome. Keep the request for deliberate retry; do not infer that it was never committed. A malformed success response similarly does not mean the write failed. Future feature stores must retain drafts, prevent duplicate concurrent submissions, and discard/cancel account-scoped work on sign-out/account changes; never replay a prior account's draft under a new account. Request values are currently in-memory and are not a durable offline outbox.

The existing account loader now uses this shared path; it no longer duplicates token-refresh retry logic.

## Records and failures

- `APIRecord<Body>` carries id/kind/version/revision/updated_at/deleted/data; `APIRecordList<Body>` carries items. `APISyncResponse` uses `APIRecord<JSONValue>` for heterogeneous records and empty tombstone bodies.
- `JSONValue` preserves null, boolean, integer, floating-point, string, list and object data. For a typed body that requires fields, use JSONValue when receiving tombstones with an empty body.
- `APIClientError.conflict` retains the backend code, message, details and request ID. `error.currentRecord` decodes `details.current` when present. Not every 409 is a version conflict: check the code before proposing resolution. No conflict causes an automatic write or expected-version update.
- After explicit user conflict resolution, build a new operation with the resolved body, latest reviewed version and a new key. Do not alter the previous request while an unknown-outcome retry remains unresolved.
- `rejected` retains HTTP status, structured error details (including validation field locations) and body/header request ID. A 404 remains a 404 for the feature to interpret, such as an unsaved optional profile.
- `unauthorized`, `connection`, `decoding`, `invalidRequest` and `invalidResponse` cover transport/client cases. A malformed non-success body gets a safe status-based message rather than displaying arbitrary response content.
- `downloadPackage` uses the same authenticated transport and returns the original JSON bytes; display, privacy choices and protected storage belong to later milestones.

## Verification

The full iOS suite passed with **29 tests**: 15 existing authentication/account tests plus 14 shared-client tests. New cases cover immutable bodies/keys/versions across 401 and timeout retry, a bounded 401 retry, refresh failure, conflict current-record preservation, non-version 409, validation details, non-JSON errors and status retention, list/sync/tombstone decoding, DELETE semantics, invalid operations, authenticated downloads and cancellation.

Run the `Local` scheme's tests in Xcode or with `xcodebuild test` targeting an installed simulator. Device build verification is tracked in AGENTS.md. Tests use mocked HTTP responses; this milestone does not claim live mutation acceptance for screens not yet implemented.
