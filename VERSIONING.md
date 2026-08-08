# Versioning Policy

## Tag Format

All releases must follow the exact tag format:

```
realm-<realm>-xcode-<xcode>-r<revision>
```

### Components

- **realm**: Realm Swift version (e.g., 20.0.5, 20.1.0)
- **xcode**: Xcode version used for building (e.g., 26.6, 26.5)
- **revision**: Build revision number, starting at r1

### Examples

- `realm-20.0.5-xcode-26.6-r1` - Initial Realm 20.0.5 build with Xcode 26.6
- `realm-20.0.5-xcode-26.6-r2` - Rebuild of same version (e.g., build fix)
- `realm-20.1.0-xcode-26.6-r1` - New Realm version with same Xcode
- `realm-20.1.0-xcode-26.7-r1` - New Realm version with new Xcode

## Archive Naming

Release archives must match the tag exactly:

```
realm-xcframeworks-<tag>.zip
```

Example: `realm-xcframeworks-realm-20.0.5-xcode-26.6-r1.zip`

## Revision Increment Rules

Increment the revision number when:

- Build script changes (same source, different build process)
- Xcode version changes (same Realm source, different toolchain)
- Build configuration changes (same source, different flags)
- Bug fixes in the build pipeline (same source, fixed build)

Do NOT increment revision when:

- Realm source version changes (use new realm version)
- Breaking changes in build output (consider new major/minor version)

## Semantic Versioning Mapping

While Realm uses its own versioning, this pipeline's revision system tracks build reproducibility:

- **realm**: Maps to Realm Swift's semantic version
- **xcode**: Tracks toolchain compatibility
- **revision**: Tracks build process changes

## Git Workflow

1. Create release branch from main
2. Update `config/realm.env` with new version/revision
3. Build and package
4. Commit changes with tag
5. Push and publish release

## Checksum Validation

Every release includes a SHA256 checksum file:

```
realm-xcframeworks-<tag>.zip.sha256
```

Format: `<sha256-hash>  <filename>`

Example:
```
a1b2c3d4e5f6...  realm-xcframeworks-realm-20.0.5-xcode-26.6-r1.zip
```

The publish script validates this checksum before uploading.
