#!/bin/zsh
# Archive the app and upload it to App Store Connect for TestFlight.
#
# Before the first run:
#   1. In App Store Connect, create the app (Apps > + > New App) with bundle
#      ID com.abcapps.trivia. The bundle ID appears there after the first
#      archive below registers it, or add it at developer.apple.com.
#   2. Be signed in to your Apple account in Xcode (Settings > Accounts).
#
# Usage: scripts/testflight.sh
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
(cd Packages/TriviaKit && swift test)

rm -rf build/Trivia.xcarchive
xcodebuild archive \
  -project Trivia.xcodeproj -scheme Trivia -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Trivia.xcarchive \
  -allowProvisioningUpdates

# Uploads directly; Xcode bumps the build number if it's already taken.
xcodebuild -exportArchive \
  -archivePath build/Trivia.xcarchive \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

echo "Uploaded. It shows up in App Store Connect > TestFlight after processing (usually 5-15 minutes)."
