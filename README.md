# PipGoGo iOS

**[View the roadmap and current progress](ROADMAP.md)** — Next: **2.6 · Pre-trip check-in**.

**[Project time log](TIME_LOG.md)** — Work sessions, recorded time, and historical estimates.

SwiftUI client for PipGoGo's Google/Cognito sign-in, authenticated account, traveler profile, recurring companions, and trip creation, editing, and deletion flows. Open `pipgogo.xcodeproj` directly in Xcode.

## Backend address

Debug Simulator builds use `http://localhost:8765`; Debug device builds currently use `http://192.168.0.156:8765`. Update `PIPGOGO_BACKEND_BASE_URL` and the Debug ATS exception if the Mac address changes. Release builds intentionally use `https://api.pipgogo.invalid` until hosting exists and contain no HTTP transport exception.

## Local backend

From `pipgogo-backend`, follow its README to install dependencies and start DynamoDB Local, then run the server on port 8765, for example:

```sh
uv run python -m scripts.login_test --profile alikianus --region us-west-2
```

The iOS OAuth flow always uses real Cognito. The backend must run in Cognito auth mode to accept that access token; its default development token mode is useful for backend-only testing but will reject Cognito tokens.

## Google sign-in

Select a signing team for device builds if Xcode requests one. Run the `pipgogo` scheme, tap **Continue with Google**, complete the hosted sign-in, and allow the app to reopen through `pipgogo://auth/callback`.

## Physical iPhone on the development LAN

Debug device builds use `http://192.168.0.156:8765`; Simulator builds keep
`http://localhost:8765`. Debug includes a local-network permission message and an HTTP
exception for this specific LAN IP. Release settings are unchanged.

Start the backend from pipgogo-backend with:

```sh
uv run python -m scripts.login_test --profile alikianus --region us-west-2 --lan-ip 192.168.0.156
```

Keep both devices on the same Wi-Fi and allow the app's Local Network permission.
If your Mac's IP changes, update the Debug device URL and matching Debug plist exception.
The iOS OAuth callback remains `pipgogo://auth/callback`. The browser login test remains
a localhost-only OAuth flow; the phone uses its native sign-in and calls the LAN API.

## Cognito custom domain

The app uses `https://auth.pipgogo.com` for sign-in, token exchange, and logout.
The native callback remains `pipgogo://auth/callback`. Domain and certificate resources
are managed in the backend CloudFormation templates; see its `infra/custom-domain.md`.
Rebuild/reinstall to pick up domain configuration changes.

## Shared API client

Milestone 2.1 provides authenticated requests, immutable retry-safe writes, generic records and structured conflicts. See [the integration guide](docs/api-client.md) before adding profile or trip screens.

## Traveler profile

The signed-in account screen now includes an optional traveler profile editor. See [profile behavior and acceptance checks](docs/traveler-profile.md).

## Switching Google accounts

Sign-in uses a shared browser session and `prompt=select_account`. Cognito Essentials/Managed Login v2 forwards this to Google so it can show available browser accounts. This supersedes the private-session workaround. Accounts present only in the Gmail app may not be listed; use another account on the Google page if needed. Reopening the app while signed in still restores/refreshes its Keychain session. CloudFormation details are in the backend `infra/managed-login.md`.

Companion implementation and device acceptance: [docs/companions.md](docs/companions.md).

Trip implementation and device acceptance: [docs/trips.md](docs/trips.md).
