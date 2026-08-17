#!/bin/bash
set -euo pipefail

# Build Realm XCFrameworks from source
# Usage: ./scripts/build_xcframeworks.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
if [ -f "$PROJECT_ROOT/config/realm.env" ]; then
    source "$PROJECT_ROOT/config/realm.env"
else
    echo "Error: config/realm.env not found"
    exit 1
fi

# Validate required variables
: "${REALM_VERSION:?REALM_VERSION not set}"
: "${XCODE_VERSION:?XCODE_VERSION not set}"
: "${REALM_SOURCE_REPO:?REALM_SOURCE_REPO not set}"
: "${REALM_SOURCE_TAG:?REALM_SOURCE_TAG not set}"

# Setup directories
cd "$PROJECT_ROOT"
REALM_SOURCE_DIR="realm-swift"
BUILD_DIR="${BUILD_DIR:-build}"
OUTPUT_DIR="${OUTPUT_DIR:-build/xcframeworks}"

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== Realm XCFramework Build ==="
echo "Realm Version: $REALM_VERSION"
echo "Xcode Version: $XCODE_VERSION"
echo "Source Tag: $REALM_SOURCE_TAG"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Download Realm source archive (faster than git clone)
if [ -d "$REALM_SOURCE_DIR" ]; then
    echo "Updating existing Realm source checkout..."
    cd "$REALM_SOURCE_DIR"
    # Check if this is a proper git repo with origin remote
    if git remote get-url origin >/dev/null 2>&1; then
        git fetch origin
        git checkout "$REALM_SOURCE_TAG"
        git pull origin "$REALM_SOURCE_TAG"
    else
        # Re-download if this is an archive-imported repo without origin
        echo "Re-downloading Realm source archive (no git remote)..."
        cd "$PROJECT_ROOT"
        rm -rf "$REALM_SOURCE_DIR"
        ARCHIVE_URL="${REALM_SOURCE_REPO%.git}/archive/refs/tags/${REALM_SOURCE_TAG}.tar.gz"
        curl -L "$ARCHIVE_URL" -o "${REALM_SOURCE_TAG}.tar.gz"
        mkdir -p "$REALM_SOURCE_DIR"
        tar -xzf "${REALM_SOURCE_TAG}.tar.gz" --strip-components=1 -C "$REALM_SOURCE_DIR"
        rm "${REALM_SOURCE_TAG}.tar.gz"
        cd "$REALM_SOURCE_DIR"
        git init
        git add -A
        git commit -m "Import from ${REALM_SOURCE_TAG}"
        git tag "$REALM_SOURCE_TAG"
    fi
else
    echo "Downloading Realm source archive..."
    ARCHIVE_URL="${REALM_SOURCE_REPO%.git}/archive/refs/tags/${REALM_SOURCE_TAG}.tar.gz"
    curl -L "$ARCHIVE_URL" -o "${REALM_SOURCE_TAG}.tar.gz"
    mkdir -p "$REALM_SOURCE_DIR"
    tar -xzf "${REALM_SOURCE_TAG}.tar.gz" --strip-components=1 -C "$REALM_SOURCE_DIR"
    rm "${REALM_SOURCE_TAG}.tar.gz"
    cd "$REALM_SOURCE_DIR"
    git init
    git add -A
    git commit -m "Import from ${REALM_SOURCE_TAG}"
    git tag "$REALM_SOURCE_TAG"
fi

# Verify source version
REALM_COMMIT=$(git rev-parse HEAD)
echo "Realm Source Commit: $REALM_COMMIT"
echo ""

# Build XCFrameworks
echo "Building Realm XCFrameworks for iOS and tvOS..."
# Already in REALM_SOURCE_DIR from above

# Use Realm's official build script
sh build.sh xcframework ios tvos

# Copy XCFrameworks to output directory
echo "Copying XCFrameworks to output directory..."
cp -R build/Release/Realm.xcframework "$PROJECT_ROOT/$OUTPUT_DIR/"
cp -R build/Release/RealmSwift.xcframework "$PROJECT_ROOT/$OUTPUT_DIR/"

# Do not start signing until the copied XCFrameworks have reached a stable
# on-disk state.  The Realm build script normally runs synchronously, but this
# guard also protects against delayed filesystem work (or a future build-script
# change that leaves a child job running) modifying a slice after signing has
# started.  Two identical inventories, separated by a short delay, establish
# that no file is still being written.
wait_for_xcframework_stability() {
    local xcframework_path="$1"
    local before after

    while true; do
        before=$(find "$xcframework_path" -type f -exec stat -f '%N %z %m' {} + | LC_ALL=C sort)
        sleep 1
        after=$(find "$xcframework_path" -type f -exec stat -f '%N %z %m' {} + | LC_ALL=C sort)
        if [ "$before" = "$after" ]; then
            return 0
        fi
        echo "Waiting for $xcframework_path to become stable..."
    done
}

wait_for_xcframework_stability "$PROJECT_ROOT/$OUTPUT_DIR/Realm.xcframework"
wait_for_xcframework_stability "$PROJECT_ROOT/$OUTPUT_DIR/RealmSwift.xcframework"

# Sign every framework slice and then the enclosing XCFramework. Apple expects
# both layers to be signed for the SDK-origin signature receipt.
sign_xcframework_two_layer() {
    local xcframework_path="$1"
    local name
    name=$(basename "$xcframework_path" .xcframework)
    local identity="${REALM_SIGNING_IDENTITY:-}"

    if ! command -v codesign >/dev/null 2>&1; then
        echo "Error: codesign is required to sign $name.xcframework" >&2
        return 1
    fi

    if [ -z "$identity" ]; then
        identity=$(security find-identity -v -p codesigning 2>/dev/null \
            | awk -F '"' '/"Apple Distribution:|"iPhone Distribution:/ { print $2; exit }')
    fi

    if [ -z "$identity" ]; then
        echo "Error: no Apple Distribution signing identity found for $name.xcframework" >&2
        echo "Set REALM_SIGNING_IDENTITY to an installed Apple distribution identity." >&2
        return 1
    fi

    case "$identity" in
        "Apple Distribution:"*|"iPhone Distribution:"*)
            ;;
        *)
            echo "Error: signing identity is not an Apple distribution identity: $identity" >&2
            return 1
            ;;
    esac

    if ! security find-identity -v -p codesigning 2>/dev/null \
        | awk -F '"' -v expected="$identity" '$2 == expected { found=1 } END { exit !found }'; then
        echo "Error: selected signing identity is not installed: $identity" >&2
        return 1
    fi

    local framework_path
    local framework_count=0
    while IFS= read -r -d '' framework_path; do
        framework_count=$((framework_count + 1))
        codesign --timestamp --force -s "$identity" "$framework_path" || {
            echo "Error: failed to sign framework slice: $framework_path" >&2
            return 1
        }
    done < <(find "$xcframework_path" -type d -name '*.framework' -print0)

    if [ "$framework_count" -eq 0 ]; then
        echo "Error: no framework slices found in $xcframework_path" >&2
        return 1
    fi

    # This must remain after all inner framework signatures are complete.
    codesign --timestamp --force -s "$identity" "$xcframework_path" || {
        echo "Error: failed to sign enclosing XCFramework: $xcframework_path" >&2
        return 1
    }

    codesign -dvvv "$xcframework_path" >/dev/null 2>&1 || {
        echo "Error: enclosing XCFramework signature verification failed: $xcframework_path" >&2
        return 1
    }
    echo "Signed $name.xcframework and $framework_count framework slice(s) with: $identity"
}

sign_xcframework_two_layer "$PROJECT_ROOT/$OUTPUT_DIR/Realm.xcframework"
sign_xcframework_two_layer "$PROJECT_ROOT/$OUTPUT_DIR/RealmSwift.xcframework"

echo ""
echo "=== Build Complete ==="
echo "XCFrameworks available in: $OUTPUT_DIR"
echo "  - Realm.xcframework"
echo "  - RealmSwift.xcframework"
