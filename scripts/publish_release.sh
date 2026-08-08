#!/bin/bash
set -euo pipefail

# Publish Realm release to GitHub
# Usage: ./scripts/publish_release.sh

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
RELEASE_DIR="$PROJECT_ROOT/build/release"

cd "$PROJECT_ROOT"

echo "=== Publishing Realm Release ==="
echo "Tag: $TAG"
echo "Repository: $(git config --get remote.origin.url)"
echo ""

# Verify archive exists
if [ ! -f "$RELEASE_DIR/$ARCHIVE_NAME" ]; then
    echo "Error: Archive not found: $RELEASE_DIR/$ARCHIVE_NAME"
    echo "Run ./scripts/package_release.sh first"
    exit 1
fi

if [ ! -f "$RELEASE_DIR/$SHA256_NAME" ]; then
    echo "Error: Checksum not found: $RELEASE_DIR/$SHA256_NAME"
    echo "Run ./scripts/package_release.sh first"
    exit 1
fi

# Validate checksum
echo "Validating SHA256 checksum..."
cd "$RELEASE_DIR"
if shasum -a 256 -c "$SHA256_NAME"; then
    echo "Checksum validation passed"
else
    echo "Error: Checksum validation failed"
    exit 1
fi
cd "$PROJECT_ROOT"

echo ""

# Create git tag
echo "Creating git tag: $TAG"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists, deleting..."
    git tag -d "$TAG" || true
    git push origin ":refs/tags/$TAG" || true
fi

git tag -a "$TAG" -m "Realm $REALM_VERSION XCFrameworks (Xcode $XCODE_VERSION, revision $REVISION)"

echo ""

# Push tag to GitHub
echo "Pushing tag to GitHub..."
git push origin "$TAG"

echo ""

# Create GitHub release
echo "Creating GitHub release..."
gh release create "$TAG" \
    "$RELEASE_DIR/$ARCHIVE_NAME" \
    "$RELEASE_DIR/$SHA256_NAME" \
    "$RELEASE_DIR/manifest.json" \
    --title "Realm $REALM_VERSION XCFrameworks (Xcode $XCODE_VERSION, r$REVISION)" \
    --notes "Realm Swift $REALM_VERSION XCFrameworks built from source with Xcode $XCODE_VERSION.

**Build Details:**
- Realm Version: $REALM_VERSION
- Xcode Version: $XCODE_VERSION
- Revision: $REVISION
- Platforms: iOS, tvOS
- Build Type: Source-built

**Assets:**
- \`$ARCHIVE_NAME\` - XCFrameworks archive
- \`$SHA256_NAME\` - SHA256 checksum
- \`manifest.json\` - Build metadata

**Verification:**
\`\`\`bash
# Verify checksum
shasum -a 256 -c $SHA256_NAME

# Extract archive
unzip $ARCHIVE_NAME
\`\`\`

See VERSIONING.md for versioning policy."

echo ""
echo "=== Release Published ==="
echo "Tag: $TAG"
echo "Release URL: $(gh release view "$TAG" --json url -q '.url')"
echo ""
echo "Assets:"
gh release view "$TAG" --json assets -q '.assets[] | "\(.name) (\(.size) bytes)"'
