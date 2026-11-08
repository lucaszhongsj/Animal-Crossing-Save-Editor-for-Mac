#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_ROOT="$PWD"
TASK_OUTPUT="${ACNH_BUILD_OUTPUT:-$TASK_ROOT/dist}"
TASK_DESTINATION="$TASK_OUTPUT/ACNH Save Editor.app"
TASK_ARCH="${1:-universal}"
TASK_SCRATCH="${ACNH_BUILD_SCRATCH:-$TASK_ROOT/.build}"
TASK_ICON="${ACNH_APP_ICON:-$TASK_ROOT/AppIcon.icns}"
if [[ ! -f "$TASK_ICON" ]]; then
    printf 'App icon not found: %s\n' "$TASK_ICON" >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$TASK_SCRATCH/ModuleCache"
export SWIFT_MODULECACHE_PATH="$TASK_SCRATCH/SwiftModuleCache"
swift_package() { swift build "$@" --scratch-path "$TASK_SCRATCH" -debug-info-format none --disable-sandbox --cache-path "$TASK_ROOT/.build/cache" --config-path "$TASK_ROOT/.build/config" --security-path "$TASK_ROOT/.build/security"; }
if [[ "$TASK_ARCH" == "universal" ]]; then
    swift_package -c release --arch arm64 --arch x86_64
    TASK_BIN="$(swift_package -c release --arch arm64 --arch x86_64 --show-bin-path)"
else
    swift_package -c release
    TASK_BIN="$(swift_package -c release --show-bin-path)"
fi
mkdir -p "$TASK_OUTPUT"
TASK_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/acnh-build.XXXXXX")"
trap 'rm -rf "$TASK_STAGE"' EXIT
TASK_APP="$TASK_STAGE/ACNH Save Editor.app"
mkdir -p "$TASK_APP/Contents/MacOS" "$TASK_APP/Contents/Resources"
cp "$TASK_BIN/ACNHSaveEditor" "$TASK_APP/Contents/MacOS/ACNHSaveEditor"
for TASK_BUNDLE in "$TASK_BIN"/*.bundle; do
    [[ -d "$TASK_BUNDLE" ]] && cp -R "$TASK_BUNDLE" "$TASK_APP/Contents/Resources/"
done
cp Info.plist "$TASK_APP/Contents/Info.plist"
cp "$TASK_ICON" "$TASK_APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --options runtime --entitlements LivePockets.entitlements "$TASK_APP"
codesign --verify --deep --strict "$TASK_APP"
if [[ -e "$TASK_DESTINATION" ]]; then
    mv "$TASK_DESTINATION" "$TASK_STAGE/previous.app"
fi
if ! mv "$TASK_APP" "$TASK_DESTINATION"; then
    if [[ -e "$TASK_STAGE/previous.app" ]]; then
        mv "$TASK_STAGE/previous.app" "$TASK_DESTINATION" || trap - EXIT
    fi
    exit 1
fi
cp README.md "$TASK_OUTPUT/Read Me.md"
cp LICENSE "$TASK_OUTPUT/LICENSE-GPL-3.0.txt"
cp THIRD-PARTY-NOTICES.md "$TASK_OUTPUT/Third Party Notices.md"
printf 'Built: %s\n' "$TASK_DESTINATION"
