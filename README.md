# Realm Binaries

Reproducible build pipeline for Realm binary releases (source-built).

## Versioning Scheme

Releases follow the tag format: `realm-<realm>-xcode-<xcode>-r<revision>`

Example: `realm-20.0.5-xcode-26.6-r1`

- `realm`: Realm Swift version (e.g., 20.0.5)
- `xcode`: Xcode version (e.g., 26.6)
- `revision`: Build revision number (r1, r2, etc.)

## Quick Start

```bash
# Build Realm XCFrameworks
./scripts/build_xcframeworks.sh

# Package release
./scripts/package_release.sh

# Publish to GitHub
./scripts/publish_release.sh
```

## Configuration

Set environment variables in `config/realm.env`:

```bash
REALM_VERSION=20.0.5
XCODE_VERSION=26.6
REVISION=1
```

## Build Artifacts

- `Realm.xcframework` - Core Realm framework
- `RealmSwift.xcframework` - Swift bindings
- `realm-xcframeworks-<tag>.zip` - Release archive
- `realm-xcframeworks-<tag>.zip.sha256` - Checksum
- `manifest.json` - Build metadata

## Source Build

This pipeline builds Realm from source using the official Realm Swift repository:

```bash
sh build.sh xcframework ios tvos
```

No prebuilt binaries or Carthage dependencies are used.
