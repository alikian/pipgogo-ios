# PipPipGo iOS

GitHub: [alikian/pippipgo-ios](https://github.com/alikian/pippipgo-ios).

Public domain: **pippipgo.com** (GoDaddy registration, AWS DNS). Sign-in uses **https://auth.pippipgo.com**; the root domain does not host a website yet.

**[View the roadmap and current progress](ROADMAP.md)** — Next: **5.2a · Hosted Dev environment**.

**[Project time log](TIME_LOG.md)** — Work sessions, recorded time, and historical estimates.

Documentation uses **PipPipGo** for the app and **pippipgo** for repository and public-domain names. Existing runtime identifiers in commands and configuration retain their exact spelling so the instructions match the code and deployed resources.

SwiftUI client for PipPipGo's Google/Cognito sign-in, authenticated account, traveler profile, recurring companions, and trip creation, editing, deletion, and pre-trip check-in flows. Open `pipgogo.xcodeproj` directly in Xcode.

## Backend address

Select the **Local**, **Dev** or **Prod** Xcode scheme. Local uses the Mac backend (localhost on Simulator, LAN address on iPhone); Dev targets `https://dev.pippipgo.com`; Prod targets `https://pippipgo.com`. Dev/Prod API hosting is not deployed yet. See [build environments and switching instructions](docs/environments.md).

## Local backend

From `pippipgo-backend`, follow its README to install dependencies and start DynamoDB Local, then run the server on port 8765, for example:

```sh
uv run python -m scripts.login_test --profile alikianus --region us-west-2
```

The iOS OAuth flow always uses real Cognito. The backend must run in Cognito auth mode to accept that access token; its default development token mode is useful for backend-only testing but will reject Cognito tokens.

## Google sign-in

Select a signing team for device builds if Xcode requests one. Run the `Local` scheme, tap **Continue with Google**, complete the hosted sign-in, and allow the app to reopen through `pipgogo://auth/callback`.

## Physical iPhone on the development LAN

Local device builds use `http://192.168.0.156:8765`; Simulator builds keep
`http://localhost:8765`. Local includes a local-network permission message and an HTTP
exception for this specific LAN IP. Dev and Prod require HTTPS.

Start the backend from pippipgo-backend with:

```sh
uv run python -m scripts.login_test --profile alikianus --region us-west-2 --lan-ip 192.168.0.156
```

Keep both devices on the same Wi-Fi and allow the app's Local Network permission.
If your Mac's IP changes, update `PIPGOGO_LAN_HOST` in `Configurations/Local.xcconfig` and its HTTP exception in `pipgogo/Resources/Debug-Info.plist`.
The iOS OAuth callback remains `pipgogo://auth/callback`. The browser login test remains
a localhost-only OAuth flow; the phone uses its native sign-in and calls the LAN API.

## Cognito custom domain

The app uses `https://auth.pippipgo.com` for sign-in, token exchange, and logout.
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

Pre-trip check-in implementation and device acceptance: [docs/check-ins.md](docs/check-ins.md).
