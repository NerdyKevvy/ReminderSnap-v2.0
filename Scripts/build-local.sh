#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
# Use full Xcode, with DEVELOPER_DIR set by the caller if it is not selected globally.
xcodebuild -project ReminderSnap.xcodeproj -scheme ReminderSnap-macOS \
  -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath Build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build
mkdir -p dist
ditto Build/Build/Products/Debug/ReminderSnap.app dist/ReminderSnap.app
codesign --verify --deep --strict dist/ReminderSnap.app
echo "Local sandboxed test build: $project_dir/dist/ReminderSnap.app"
echo 'This ad-hoc build is not an App Store upload archive.'
