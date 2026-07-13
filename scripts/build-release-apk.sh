#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$project_root/scripts/verify-release-config.sh"
cd "$project_root"
flutter build apk --release "$@"

apk=""
for candidate in \
  "build/app/outputs/apk/release/app-release.apk" \
  "build/app/outputs/flutter-apk/app-release.apk"; do
  if [[ -f "$candidate" ]]; then
    apk="$candidate"
    break
  fi
done

if [[ -z "$apk" ]]; then
  echo "Release APK was not produced." >&2
  exit 1
fi

shasum -a 256 "$apk"
