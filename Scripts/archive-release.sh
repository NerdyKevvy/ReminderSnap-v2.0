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
release_version="${RELEASE_VERSION:-2.1}"
release_build="${RELEASE_BUILD:-20107}"
archive_path="$project_dir/Artifacts/ReminderSnap-$platform-$release_version-$release_build.xcarchive"
if [[ -e "$archive_path" ]]; then
  echo 'This archive already exists. Preserve it or choose a new build number/path before archiving again.' >&2
  exit 1
fi
# Configure signing in Xcode first. This script only archives; distribution
# export, upload and accepting account agreements are separate operations.
# Explicit provisioning is opt-in for a previously approved developer account.
provisioning_options=()
if [[ "${RELEASE_ALLOW_PROVISIONING:-0}" == 1 ]]; then
  provisioning_options=(-allowProvisioningUpdates)
fi
xcodebuild -project ReminderSnap.xcodeproj -scheme "ReminderSnap-$platform" \
  -configuration Release -destination "generic/platform=$platform" \
  -derivedDataPath Build -archivePath "$archive_path" \
  "${provisioning_options[@]}" \
  DEVELOPMENT_TEAM="$RELEASE_TEAM_ID" MARKETING_VERSION="$release_version" CURRENT_PROJECT_VERSION="$release_build" REMINDERSNAP_PRIVACY_POLICY_URL="$RELEASE_PRIVACY_URL" archive
echo "Archive: $archive_path"
echo 'Validate and distribute with Xcode Organizer after the release checklist is complete.'
