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

echo ""
echo "=== Build Complete ==="
echo "XCFrameworks available in: $OUTPUT_DIR"
echo "  - Realm.xcframework"
echo "  - RealmSwift.xcframework"
