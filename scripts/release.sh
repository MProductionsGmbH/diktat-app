#!/bin/bash
set -euo pipefail

# Diktat: build a release on this Mac and upload it to GitHub.
#
# GitHub only stores the result (tag, release, Diktat.dmg, Diktat.zip, appcast.xml); nothing is
# built there. The script stops at the first thing that is not right, so a release never goes
# out unsigned, unnotarized, untested or with a build number the update check would ignore.
#
#   scripts/release.sh                 build, sign, notarize, publish
#   scripts/release.sh --check         only the checks, builds nothing
#   scripts/release.sh --no-publish    everything but the upload; the files stay in dist/
#   scripts/release.sh --skip-notarize together with --no-publish only, to try the build
#
# Needed once on this Mac (see docs/releasing.md):
#   - the certificate "Developer ID Application" in the keychain
#   - notarization credentials, stored with
#       xcrun notarytool store-credentials diktat-notary --apple-id <id> --team-id <team>
#   - Sparkle's private update key in the keychain (made by generate_keys)
#   - gh, signed in with access to the repository

CHECK_ONLY=false
PUBLISH=true
NOTARIZE=true
for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=true ;;
        --no-publish) PUBLISH=false ;;
        --skip-notarize) NOTARIZE=false ;;
        *)
            echo "Unbekannte Option: $arg"
            echo "Verwendung: scripts/release.sh [--check] [--no-publish] [--skip-notarize]"
            exit 1
            ;;
    esac
done

if [ "$NOTARIZE" = false ] && [ "$PUBLISH" = true ]; then
    echo "❌ --skip-notarize geht nur zusammen mit --no-publish: ohne Beglaubigung wird nichts veröffentlicht."
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO="${DIKTAT_REPO:-MProductionsGmbH/diktat-app}"
NOTARY_PROFILE="${DIKTAT_NOTARY_PROFILE:-diktat-notary}"
DERIVED_DATA="$HOME/Library/Caches/diktat-build/derivedData"
SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"
DIST="$ROOT/dist"

fail() {
    echo "❌ $1"
    exit 1
}

# What must hold for a release that goes out. A trial run (--no-publish) only says so.
require_for_publishing() {
    if [ "$PUBLISH" = true ]; then
        fail "$1"
    fi
    echo "⚠️  $1 (Probelauf, es wird nichts veröffentlicht.)"
}

project_value() {
    grep -m1 "$1" DiktatMac/project.yml | sed -E 's/.*"([^"]+)".*/\1/'
}

VERSION="$(project_value MARKETING_VERSION)"
BUILD="$(project_value CURRENT_PROJECT_VERSION)"
PUBLIC_KEY="$(project_value SPARKLE_PUBLIC_ED_KEY)"
TAG="v$VERSION"

echo "🔎 Prüfe die Voraussetzungen für $TAG (Build $BUILD) ..."

# --- The source: what is released is exactly what is on GitHub's main.
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || require_for_publishing "Nicht auf dem Branch main."
[ -z "$(git status --porcelain)" ] || require_for_publishing "Es gibt nicht committete Änderungen. Erst committen."
git fetch --quiet origin main
SHA="$(git rev-parse HEAD)"
[ "$SHA" = "$(git rev-parse origin/main)" ] || require_for_publishing "main ist nicht mit GitHub abgeglichen. Erst pushen (oder pullen)."

# --- The version: new, and with a build number the update check accepts.
command -v gh >/dev/null 2>&1 || fail "gh fehlt (brew install gh)."
gh auth status >/dev/null 2>&1 || fail "gh ist nicht angemeldet (gh auth login)."
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    require_for_publishing "$TAG ist schon veröffentlicht. MARKETING_VERSION und CURRENT_PROJECT_VERSION in DiktatMac/project.yml anheben."
fi
case "$BUILD" in
    ''|*[!0-9]*) fail "CURRENT_PROJECT_VERSION ist keine ganze Zahl: $BUILD" ;;
esac
# Sparkle compares the build number. One that did not grow is never offered as an update.
PREVIOUS_BUILD="$(gh release download --repo "$REPO" --pattern appcast.xml --output - 2>/dev/null \
    | sed -n -E 's/.*<sparkle:version>([0-9]+)<\/sparkle:version>.*/\1/p' | head -1 || true)"
if [ -n "$PREVIOUS_BUILD" ] && [ "$BUILD" -le "$PREVIOUS_BUILD" ]; then
    require_for_publishing "Build $BUILD ist nicht grösser als der veröffentlichte Build $PREVIOUS_BUILD. CURRENT_PROJECT_VERSION anheben."
fi

# --- Signing: a Developer ID, never ad hoc.
IDENTITY="${DIKTAT_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(.+)".*/\1/' || true)"
fi
[ -n "$IDENTITY" ] || fail "Kein Zertifikat «Developer ID Application» im Schlüsselbund."

# --- Notarization: the stored credentials must work before the long build starts.
if [ "$NOTARIZE" = true ]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "❌ Die Zugangsdaten für die Beglaubigung fehlen oder sind ungültig (Profil «$NOTARY_PROFILE»)."
        echo "   Einmal im Terminal einrichten, das Passwort ist ein app-spezifisches von appleid.apple.com:"
        echo "   xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <Apple-ID> --team-id <Team-ID>"
        exit 1
    fi
fi

command -v xcodegen >/dev/null 2>&1 || fail "xcodegen fehlt (brew install xcodegen)."

echo "✅ Voraussetzungen erfüllt: $TAG, Build $BUILD, Commit ${SHA:0:7}"
echo "   Signatur: $IDENTITY"
if [ "$CHECK_ONLY" = true ]; then
    echo "   (--check: es wird nichts gebaut. Der Update-Schlüssel wird erst nach dem Build geprüft.)"
    exit 0
fi

# --- Tests first: a version with failing tests is not released.
echo "🧪 Tests ..."
(cd DiktatMac && xcodegen generate >/dev/null)
TEST_LOG="$(mktemp -t diktat-tests)"
# The same call as CI: this Mac's architecture only, as the tests need no universal build.
if ! xcodebuild -project DiktatMac/DiktatMac.xcodeproj -scheme DiktatMac -configuration Debug \
    -destination 'platform=macOS,arch=arm64' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    -derivedDataPath "$DERIVED_DATA" test >"$TEST_LOG" 2>&1; then
    grep -E "error:|failed|Executed [0-9]+ tests" "$TEST_LOG" | tail -20 || true
    fail "Die Tests laufen nicht durch. Das ganze Protokoll: $TEST_LOG"
fi
grep -E "Executed [0-9]+ tests" "$TEST_LOG" | tail -1
rm -f "$TEST_LOG"

# --- Build and sign.
DIKTAT_SIGN_IDENTITY="$IDENTITY" ./build.sh --release
APP="$ROOT/Diktat.app"

# The app that goes out carries the version and build this script checked.
BUILT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")"
[ "$BUILT_VERSION" = "$VERSION" ] && [ "$BUILT_BUILD" = "$BUILD" ] \
    || fail "Die gebaute App ist $BUILT_VERSION ($BUILT_BUILD), erwartet war $VERSION ($BUILD)."

# --- The update key: the one in the keychain must be the one the installed apps trust.
[ -x "$SPARKLE_BIN/sign_update" ] || fail "Sparkles sign_update fehlt unter $SPARKLE_BIN."
# From a key file (DIKTAT_SPARKLE_KEY_FILE, or the default place when a file is there), else from
# the keychain. The file is for a Mac whose keychain will not let sign_update at the key.
SPARKLE_KEY_FILE="${DIKTAT_SPARKLE_KEY_FILE:-$HOME/.config/diktat/sparkle-update-key}"
if [ -f "$SPARKLE_KEY_FILE" ]; then
    SPARKLE_KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
    # The file must hold the key the installed apps trust: sign and check against project.yml.
    PROBE="$(mktemp -t diktat-probe)"
    echo "diktat" > "$PROBE"
    PROBE_SIGNATURE="$("$SPARKLE_BIN/sign_update" --ed-key-file "$SPARKLE_KEY_FILE" -p "$PROBE" 2>/dev/null || true)"
    if [ -z "$PROBE_SIGNATURE" ] || ! swift "$ROOT/scripts/verify-ed25519.swift" "$PUBLIC_KEY" "$PROBE_SIGNATURE" "$PROBE" >/dev/null 2>&1; then
        rm -f "$PROBE"
        fail "Die Schlüsseldatei $SPARKLE_KEY_FILE passt nicht zu SPARKLE_PUBLIC_ED_KEY in project.yml."
    fi
    rm -f "$PROBE"
else
    SPARKLE_KEY_ARGS=()
    KEYCHAIN_PUBLIC_KEY="$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null || true)"
    [ -n "$KEYCHAIN_PUBLIC_KEY" ] || fail "Kein Update-Schlüssel von Sparkle im Schlüsselbund und keine Schlüsseldatei unter $SPARKLE_KEY_FILE."
    [ "$KEYCHAIN_PUBLIC_KEY" = "$PUBLIC_KEY" ] \
        || fail "Der Update-Schlüssel im Schlüsselbund passt nicht zu SPARKLE_PUBLIC_ED_KEY in project.yml. Installierte Apps würden das Update ablehnen."
fi

# --- Notarize.
rm -rf "$DIST"
mkdir -p "$DIST/dmg"
if [ "$NOTARIZE" = true ]; then
    echo "📮 Beglaubigung bei Apple ..."
    ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
    RESULT="$(xcrun notarytool submit "$DIST/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 || true)"
    echo "$RESULT"
    rm -f "$DIST/notarize.zip"
    echo "$RESULT" | grep -q "status: Accepted" \
        || fail "Apple hat die App nicht angenommen. Gründe: xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE"
    xcrun stapler staple "$APP"
    spctl --assess --type execute --verbose "$APP"
else
    echo "⚠️  Ohne Beglaubigung (--skip-notarize): nur zum Ausprobieren."
fi

# --- Package.
echo "📦 Packe ..."
cp -R "$APP" "$DIST/dmg/Diktat.app"
ln -s /Applications "$DIST/dmg/Applications"
hdiutil create -quiet -volname "Diktat" -srcfolder "$DIST/dmg" -ov -format UDZO "$DIST/Diktat.dmg"
rm -rf "$DIST/dmg"
ditto -c -k --keepParent "$APP" "$DIST/Diktat.zip"
(cd "$DIST" && shasum -a 256 Diktat.dmg Diktat.zip | tee SHA256SUMS.txt)

# --- Sign the update and write the appcast.
SIGNATURE="$("$SPARKLE_BIN/sign_update" ${SPARKLE_KEY_ARGS[@]+"${SPARKLE_KEY_ARGS[@]}"} -p "$DIST/Diktat.zip" || true)"
[ -n "$SIGNATURE" ] || fail "Das Update liess sich nicht signieren. Hat der Schlüsselbund den Zugriff auf den Update-Schlüssel erlaubt? Sonst den Schlüssel als Datei ablegen, siehe docs/releasing.md."
LENGTH="$(stat -f%z "$DIST/Diktat.zip")"
MINIMUM_SYSTEM="$(grep -m1 'macOS:' DiktatMac/project.yml | sed -E 's/.*"([^"]+)".*/\1/')"
REPO_URL="https://github.com/$REPO"
cat > "$DIST/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschek.org/xmlns/update" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Diktat</title>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>$(date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MINIMUM_SYSTEM:-14.0}</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>${REPO_URL}/releases/tag/${TAG}</sparkle:fullReleaseNotesLink>
      <enclosure url="${REPO_URL}/releases/download/${TAG}/Diktat.zip" sparkle:edSignature="${SIGNATURE}" length="${LENGTH}" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

if [ "$PUBLISH" = false ]; then
    echo ""
    echo "✅ Gebaut, aber nicht veröffentlicht (--no-publish). Die Dateien liegen in $DIST"
    exit 0
fi

# --- Publish. Nothing changed on main while this ran?
git fetch --quiet origin main
[ "$SHA" = "$(git rev-parse origin/main)" ] || fail "main hat sich während des Builds geändert. Nicht veröffentlicht, die Dateien liegen in $DIST"

echo "🚀 Lade $TAG zu GitHub hoch ..."
# A normal release, not a pre-release: only then does "releases/latest" point at it. The tag
# does not exist yet; --target makes the release create it on the built commit.
gh release create "$TAG" "$DIST/Diktat.dmg" "$DIST/Diktat.zip" "$DIST/SHA256SUMS.txt" "$DIST/appcast.xml" \
    --repo "$REPO" \
    --target "$SHA" \
    --title "Diktat $TAG" \
    --notes-file .github/release-notes.md

echo ""
echo "✅ $TAG ist veröffentlicht: $REPO_URL/releases/tag/$TAG"
