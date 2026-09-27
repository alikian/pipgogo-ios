# Local, Dev and Prod builds

Choose **Local**, **Dev** or **Prod** in Xcode's scheme picker, choose a device,
then Run. A footer in the app shows **Build: Local**, **Build: Dev** or **Build: Prod**,
including before sign-in. The label describes the build, not server availability. Each scheme uses its matching configuration for Run, Test, Profile,
Analyze and Archive. This is a build-time choice; switching requires rebuilding
and installing. The old `pipgogo` scheme and Debug/Release configuration names
have been replaced. The project, target and Swift module remain `pipgogo`.

| Scheme | Home-screen name | API base URL | Status |
| --- | --- | --- | --- |
| Local | PipPipGo Local | Simulator: `http://localhost:8765`; device: `http://192.168.0.156:8765` | Uses the Mac backend, existing Cognito and development DynamoDB |
| Dev | PipPipGo Dev | `https://dev.pippipgo.com` | App configuration ready; hosted API not deployed |
| Prod | PipPipGo | `https://pippipgo.com` | App configuration ready; hosted API not deployed |

All three retain bundle ID `com.pipgogo.ios` and the existing native OAuth URLs.
They **replace one another** on a device, rather than installing side by side.
Local keeps the existing Keychain session. Dev and Prod use separate Keychain
service names, so an installed build does not restore another environment's token
set. Browser Google sessions can still be shared.

## Configuration files

- `Configurations/Local.xcconfig`: edit `PIPGOGO_LAN_HOST` when the Mac address
  changes, and update the matching `NSExceptionDomains` key in
  `pipgogo/Resources/Debug-Info.plist`. Xcode expands values but not plist dictionary
  keys. The simulator override continues to use localhost.
- `Configurations/Dev.xcconfig`: development API origin and app label.
- `Configurations/Prod.xcconfig`: production API origin and app label.
- `Configurations/Common.xcconfig`: current public Cognito domain and client ID.
  Override these settings in the relevant environment file when separate
  authentication resources are deployed. Never put secrets in these files.

Local includes the local-network usage description and narrowly scoped HTTP
exceptions. Dev and Prod use the hosted plist with no HTTP exception or local
network permission description. Runtime validation rejects HTTP or another
host for Dev/Prod; there is no automatic fallback to the Mac backend.

Authentication **currently uses the same existing Cognito foundation** in all
three configurations. Separate token storage does not create separate accounts,
user pools or databases. Hosting milestone 5.2 must establish the intended
Dev/Prod authentication and data isolation before release. This work changes no
AWS resources, DNS, OAuth callbacks or Google Console settings.

## Run and verify

```sh
xcodebuild test -project pipgogo.xcodeproj -scheme Local \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild build -project pipgogo.xcodeproj -scheme Dev \
  -destination 'generic/platform=iOS'
xcodebuild archive -project pipgogo.xcodeproj -scheme Prod \
  -destination 'generic/platform=iOS' -archivePath /tmp/PipPipGo-Prod.xcarchive
```

Use an available simulator name/ID and the configured signing team. Prod uses
optimized code with testability disabled for normal builds; if running its unit
tests, pass `ENABLE_TESTABILITY=YES` explicitly for that test build. Local and Dev
use debug compilation settings. Schemes preserve their API selection during
Archive; archiving Local does not turn it into Prod.

Local phones need the Mac backend running, the same LAN and local-network
permission. Start the existing Cognito/DynamoDB harness from the backend checkout:

```sh
uv run python -m scripts.login_test --profile alikianus --region us-west-2 --lan-ip 192.168.0.156
```

## Hosted API prerequisites

Dev HTTPS hosting is deployed on standard ECS Fargate (September 27, 2026);
Prod hosting remains pending. Complete device acceptance against Dev.
The client appends existing `/v1/...` API paths, for example
`https://dev.pippipgo.com/v1/me` and `https://pippipgo.com/v1/me`.
The production apex will also host the planned public website (5.3): configure
routing so `/v1/*` reaches the API and website paths reach the website. Preserve
`auth.pippipgo.com` and coordinate replacement of the root placeholder DNS record
with the certificate stack. The build configuration alone does not prove device acceptance.

Before release, verify the chosen identity/data environment and Google sign-in,
refresh, logout, account isolation and trip flows on a physical phone without
the Mac backend. Build/tests alone do not constitute hosted environment acceptance.


## Validation — September 26, 2026

110 tests passed in Local; the 7 environment tests also passed in Dev and Prod.
Prod unit tests explicitly enabled testability; its signed device build used normal
optimized settings. All three signed device builds passed. Inspection of their
built plists and signatures verified the exact backend origins, app labels, shared
Cognito configuration and Local-only HTTP exceptions. Every scheme action,
including Archive, selects its matching environment. These variants were not
installed on a physical phone in this session; hosted API acceptance remains open.

The next check is **5.2a — hosted Dev physical-device acceptance**. See the roadmap for
deployment and physical-device acceptance requirements.

The Dev build was installed on Ali’s iPhone 12 on September 27. Remote launch
reported the device locked; do not count installation as sign-in or trip acceptance.
Local and Dev share development accounts/data. Prod requires its own persistence
and matching Cognito settings before release. Both repositories default to `develop`.
