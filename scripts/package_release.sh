#!/bin/bash
set -euo pipefail

# Package Realm XCFrameworks for release
# Usage: ./scripts/package_release.sh

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
: "${REVISION:?REVISION not set}"

# Generate tag and archive name
TAG="realm-${REALM_VERSION}-xcode-${XCODE_VERSION}-r${REVISION}"
ARCHIVE_NAME="realm-xcframeworks-${TAG}.zip"
SHA256_NAME="${ARCHIVE_NAME}.sha256"

# Directories
OUTPUT_DIR="${OUTPUT_DIR:-build/xcframeworks}"
RELEASE_DIR="$PROJECT_ROOT/build/release"

mkdir -p "$RELEASE_DIR"
cd "$PROJECT_ROOT"

echo "=== Packaging Realm Release ==="
echo "Tag: $TAG"
echo "Archive: $ARCHIVE_NAME"
echo ""

# Verify XCFrameworks exist
if [ ! -d "$OUTPUT_DIR/Realm.xcframework" ]; then
    echo "Error: Realm.xcframework not found in $OUTPUT_DIR"
    echo "Run ./scripts/build_xcframeworks.sh first"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR/RealmSwift.xcframework" ]; then
    echo "Error: RealmSwift.xcframework not found in $OUTPUT_DIR"
    echo "Run ./scripts/build_xcframeworks.sh first"
    exit 1
fi

# Get Realm source commit
if [ -d "realm-swift" ]; then
    cd realm-swift
    REALM_COMMIT=$(git rev-parse HEAD)
    REALM_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "none")
    cd "$PROJECT_ROOT"
else
    REALM_COMMIT="unknown"
    REALM_TAG="unknown"
fi

# Get Xcode version info
XCODE_BUILD_VERSION=$(xcodebuild -version | head -1)
XCODE_BUILD_NUMBER=$(xcodebuild -version | tail -1)
SWIFT_VERSION=$(swift --version | head -1)

# Create manifest
cat > "$RELEASE_DIR/manifest.json" << EOF
{
  "tag": "$TAG",
  "realm": {
    "version": "$REALM_VERSION",
    "source_commit": "$REALM_COMMIT",
    "source_tag": "$REALM_TAG"
  },
  "xcode": {
    "semantic_version": "$XCODE_VERSION",
    "build_version": "$XCODE_BUILD_VERSION",
    "build_number": "$XCODE_BUILD_NUMBER"
  },
  "swift": "$SWIFT_VERSION",
  "platforms": ["iOS", "tvOS"],
  "build_command": "sh build.sh xcframework ios tvos",
  "build_type": "source-built",
  "revision": "$REVISION",
  "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "Created manifest.json"
echo ""

# Create archive
echo "Creating archive: $ARCHIVE_NAME"
cd "$OUTPUT_DIR"
zip -r "$RELEASE_DIR/$ARCHIVE_NAME" \
    Realm.xcframework \
    RealmSwift.xcframework \
    ../release/manifest.json

cd "$PROJECT_ROOT"

# Generate SHA256 checksum
echo "Generating SHA256 checksum..."
cd "$RELEASE_DIR"
shasum -a 256 "$ARCHIVE_NAME" > "$SHA256_NAME"

echo ""
echo "=== Package Complete ==="
echo "Archive: $RELEASE_DIR/$ARCHIVE_NAME"
echo "Checksum: $RELEASE_DIR/$SHA256_NAME"
echo "Manifest: $RELEASE_DIR/manifest.json"
echo ""
echo "Archive contents:"
unzip -l "$RELEASE_DIR/$ARCHIVE_NAME"
