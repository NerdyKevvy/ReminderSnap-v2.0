#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
platform="${1:-}"
if [[ "$platform" != macOS && "$platform" != iOS ]]; then
  echo 'Usage: DEVELOPER_DIR=... RELEASE_TEAM_ID=... RELEASE_PRIVACY_URL=https://... zsh Scripts/archive-release.sh macOS|iOS' >&2
  exit 1
fi
: "${RELEASE_TEAM_ID:?Provide the approved Apple Developer team ID}"
: "${RELEASE_PRIVACY_URL:?Publish and verify the privacy policy URL before archiving}"
if [[ "$RELEASE_PRIVACY_URL" != https://* ]]; then
  echo 'The privacy policy must use a public HTTPS URL.' >&2
  exit 1
fi
mkdir -p Artifacts
archive_path="$project_dir/Artifacts/ReminderSnap-$platform-2.0.xcarchive"
if [[ -e "$archive_path" ]]; then
  echo 'This archive already exists. Preserve it or choose a new build number/path before archiving again.' >&2
  exit 1
fi
# Does not automatically create signing credentials, accept agreements, or upload.
# Configure signing in Xcode first. Opening Organizer is the next manual gate.
xcodebuild -project ReminderSnap.xcodeproj -scheme "ReminderSnap-$platform" \
  -configuration Release -destination "generic/platform=$platform" \
  -derivedDataPath Build -archivePath "$archive_path" \
  DEVELOPMENT_TEAM="$RELEASE_TEAM_ID" REMINDERSNAP_PRIVACY_POLICY_URL="$RELEASE_PRIVACY_URL" archive
echo "Archive: $archive_path"
echo 'Validate and distribute with Xcode Organizer after the release checklist is complete.'
