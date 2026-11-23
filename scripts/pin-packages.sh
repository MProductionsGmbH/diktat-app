#!/bin/bash
set -euo pipefail

# The exact versions of all Swift packages, also the ones the direct packages bring along, are
# written down in DiktatMac/Package.resolved. Xcode keeps its copy inside the generated project,
# which is not in the repository, so every build first puts the written-down versions there.
#
#   scripts/pin-packages.sh          use the versions of the repository (after xcodegen generate)
#   scripts/pin-packages.sh --save   write down what Xcode resolved, after updating packages
#
# To update packages: raise the versions in DiktatMac/project.yml, run xcodegen generate, let
# Xcode resolve (xcodebuild -resolvePackageDependencies), then --save and commit the file.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PINNED="$ROOT/DiktatMac/Package.resolved"
IN_PROJECT="$ROOT/DiktatMac/DiktatMac.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

if [ "${1:-}" = "--save" ]; then
    [ -f "$IN_PROJECT" ] || { echo "❌ Xcode hat noch nichts aufgelöst: $IN_PROJECT fehlt."; exit 1; }
    cp "$IN_PROJECT" "$PINNED"
    echo "✅ Paket-Versionen festgehalten in DiktatMac/Package.resolved"
    exit 0
fi

[ -f "$PINNED" ] || { echo "❌ DiktatMac/Package.resolved fehlt."; exit 1; }
[ -d "$ROOT/DiktatMac/DiktatMac.xcodeproj" ] || { echo "❌ Erst das Projekt erzeugen (xcodegen generate)."; exit 1; }
mkdir -p "$(dirname "$IN_PROJECT")"
cp "$PINNED" "$IN_PROJECT"
