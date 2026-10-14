#!/bin/sh
set -eu
# Run after `sh build.sh xcframework ...` in CI. This harness intentionally
# downloads published binaries; it never recompiles Realm.
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
CACHE="$ROOT/.cache"
SIMULATOR_ID=${SIMULATOR_ID:-$(xcrun simctl list devices available | awk '/iPad Air 11-inch \(M4\)/ {gsub(/[()]/,"",$NF); print $NF; exit}')}
TAG_A=realm-20.0.5-xcode-26.6-r2
TAG_B=realm-20.0.5-xcode-27.0-beta.5-r1
download() {
  tag=$1; dir=$2
  mkdir -p "$dir"
  zip=$(find "$dir" -maxdepth 1 -name '*.zip' -print -quit || true)
  sha=$(find "$dir" -maxdepth 1 -name '*.sha256' -print -quit || true)
  if [ -z "$zip" ] || [ -z "$sha" ] || ! (cd "$dir" && shasum -a 256 -c "$(basename "$sha")" >/dev/null 2>&1); then
    gh release download "$tag" --repo bastianX6/realm-binaries --pattern '*.zip' --pattern '*.sha256' --dir "$dir"
  fi
  sha=$(find "$dir" -maxdepth 1 -name '*.sha256' -print -quit || true)
  zip=$(find "$dir" -maxdepth 1 -name '*.zip' -print -quit)
  if [ -n "$sha" ]; then (cd "$dir" && shasum -a 256 -c "$(basename "$sha")"); fi
  unzip -q -o "$zip" -d "$dir/unpacked"
  find "$dir/unpacked" "$dir/xcframeworks" -name Realm.xcframework -exec cp -R {} "$ROOT/Binaries/Realm.xcframework" \; 2>/dev/null || true
  find "$dir/unpacked" "$dir/xcframeworks" -name RealmSwift.xcframework -exec cp -R {} "$ROOT/Binaries/RealmSwift.xcframework" \; 2>/dev/null || true
}
CREATOR="$ROOT/creator-A"; OPENER="$ROOT/opener-B"
rm -rf "$CREATOR/Binaries" "$CREATOR/.build" "$OPENER/Binaries" "$OPENER/.build"
mkdir -p "$CREATOR/Binaries" "$OPENER/Binaries" "$OPENER/Fixtures"
download "$TAG_A" "$CACHE/A"
cp -R "$CACHE/A"/unpacked/*/Realm.xcframework "$CREATOR/Binaries/Realm.xcframework" 2>/dev/null || find "$CACHE/A" -name Realm.xcframework -exec cp -R {} "$CREATOR/Binaries/Realm.xcframework" \;
cp -R "$CACHE/A"/unpacked/*/RealmSwift.xcframework "$CREATOR/Binaries/RealmSwift.xcframework" 2>/dev/null || find "$CACHE/A" -name RealmSwift.xcframework -exec cp -R {} "$CREATOR/Binaries/RealmSwift.xcframework" \;
download "$TAG_B" "$CACHE/B"
cp -R "$CACHE/B"/unpacked/*/Realm.xcframework "$OPENER/Binaries/Realm.xcframework" 2>/dev/null || find "$CACHE/B" -name Realm.xcframework -exec cp -R {} "$OPENER/Binaries/Realm.xcframework" \;
cp -R "$CACHE/B"/unpacked/*/RealmSwift.xcframework "$OPENER/Binaries/RealmSwift.xcframework" 2>/dev/null || find "$CACHE/B" -name RealmSwift.xcframework -exec cp -R {} "$OPENER/Binaries/RealmSwift.xcframework" \;
(cd "$CREATOR" && DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer xcodebuild -list)
(cd "$OPENER" && DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer xcodebuild -list)
(cd "$CREATOR" && DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer xcodebuild build-for-testing -scheme creatorA-Package -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)" -derivedDataPath .build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")
(cd "$CREATOR" && DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer xcodebuild test-without-building -scheme creatorA-Package -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)" -derivedDataPath .build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")
fixture=$(find "$HOME/Library/Developer/CoreSimulator/Devices" -name fixture-A.realm -type f -newermt '-5 minutes' -print0 | xargs -0 ls -t | head -1)
cp "$fixture" "$OPENER/Fixtures/fixture-A.realm"; cp "$fixture" "$ROOT/fixtures/fixture-A.realm"; shasum -a 256 "$fixture" "$OPENER/Fixtures/fixture-A.realm" "$ROOT/fixtures/fixture-A.realm"
(cd "$OPENER" && DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer xcodebuild build-for-testing -scheme openerB-Package -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)" -derivedDataPath .build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")
log="$OPENER/.build/opener.log"
(cd "$OPENER" && DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer xcodebuild test-without-building -scheme openerB-Package -destination "platform=iOS Simulator,name=iPad Air 11-inch (M4)" -derivedDataPath .build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="") | tee "$log"
grep -F '[abopen] override open=ok pk=recordID count=3' "$log" >/dev/null
