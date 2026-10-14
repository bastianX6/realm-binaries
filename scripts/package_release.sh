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
: "${REALM_SOURCE_REPO:?REALM_SOURCE_REPO not set}"
: "${REALM_SOURCE_TAG:?REALM_SOURCE_TAG not set}"

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

# Resolve the configured source tag against the official remote. Local archive
# imports have synthetic commits, so HEAD is not reliable source provenance.
REALM_TAG="$REALM_SOURCE_TAG"
REALM_COMMIT=$(git ls-remote "$REALM_SOURCE_REPO" "refs/tags/$REALM_TAG^{}" "refs/tags/$REALM_TAG" \
    | awk -v tag="refs/tags/$REALM_TAG" '$2 == tag "^{}" { peeled=$1 } $2 == tag { direct=$1 } END { if (peeled != "") print peeled; else print direct }')
if [ -z "$REALM_COMMIT" ] || ! [[ "$REALM_COMMIT" =~ ^[0-9a-fA-F]{40}$ ]]; then
    echo "Error: could not resolve $REALM_TAG to a commit at $REALM_SOURCE_REPO" >&2
    exit 1
fi
if [ -n "${REALM_LOCAL_IMPORT_COMMIT:-}" ]; then
    if ! [[ "$REALM_LOCAL_IMPORT_COMMIT" =~ ^[0-9a-fA-F]{40}$ ]]; then
        echo "Error: REALM_LOCAL_IMPORT_COMMIT must be a 40-character commit hash" >&2
        exit 1
    fi
    REALM_COMMIT="$REALM_LOCAL_IMPORT_COMMIT"
fi

# Get Xcode version info
XCODE_VERSION_OUTPUT=$(xcodebuild -version)
XCODE_BUILD_VERSION=$(printf '%s\n' "$XCODE_VERSION_OUTPUT" | sed -n '1p')
XCODE_BUILD_NUMBER=$(printf '%s\n' "$XCODE_VERSION_OUTPUT" | sed -n '2p')
SWIFT_VERSION_OUTPUT=$(swift --version)
SWIFT_VERSION=$(printf '%s\n' "$SWIFT_VERSION_OUTPUT" | sed -n '1p')

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
    RealmSwift.xcframework

cd "$PROJECT_ROOT"

# Add manifest to archive
echo "Adding manifest to archive..."
cd "$RELEASE_DIR"
zip -u "$ARCHIVE_NAME" manifest.json

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
