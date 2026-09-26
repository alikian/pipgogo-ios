# pipgogo iOS

Initial SwiftUI client for pipgogo's Google/Cognito sign-in and authenticated account flow. Open `pipgogo.xcodeproj` directly in Xcode.

## Backend address

Debug builds use `http://localhost:8765`. Change `PIPGOGO_BACKEND_BASE_URL` in the app target's Debug build settings when testing on a physical device. Release builds intentionally use `https://api.pipgogo.invalid` until hosting exists and contain no HTTP transport exception.

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
