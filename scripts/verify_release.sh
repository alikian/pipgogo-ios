#!/bin/sh
# Usage: verify_release.sh /path/to/pipgogo.app expected-build expected-version
set -eu
[ "$#" -eq 3 ] || { echo "Usage: $0 app-path build-number marketing-version" >&2; exit 1; }
plist="$1/Info.plist"
check() {
    actual=$(/usr/libexec/PlistBuddy -c "Print :$1" "$plist")
    if [ "$actual" != "$2" ]; then
        echo "Release validation failed: $1 does not match the expected value." >&2
        exit 1
    fi
}
check CFBundleIdentifier com.pipgogo.ios
check CFBundleDisplayName PipPipGo
check AppEnvironment prod
check BackendBaseURL https://api.pippipgo.com
check CognitoDomain https://auth.pippipgo.com
check CognitoClientID 23sk8qfmpotjj40jbnl9tn33em
check CFBundleVersion "$2"
check CFBundleShortVersionString "$3"
if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity' "$plist" >/dev/null 2>&1; then
    echo "Release validation failed: unexpected transport exceptions." >&2
    exit 1
fi
echo "Verified PipPipGo $3 ($2), production API and isolated production identity."
