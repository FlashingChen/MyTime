#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
properties_file="$project_root/android/key.properties"

if [[ ! -f "$properties_file" ]]; then
  echo "Missing android/key.properties. Copy android/key.properties.example and keep it untracked." >&2
  exit 1
fi

key_alias="$(sed -n 's/^keyAlias=//p' "$properties_file" | head -n 1)"
store_file="$(sed -n 's/^storeFile=//p' "$properties_file" | head -n 1)"

if [[ -z "$key_alias" || -z "$store_file" ]]; then
  echo "android/key.properties must define keyAlias and storeFile." >&2
  exit 1
fi

if [[ ! -f "$store_file" ]]; then
  echo "The configured Android keystore does not exist: $store_file" >&2
  exit 1
fi

for service in \
  com.mytime.mytime.android.release.store-password \
  com.mytime.mytime.android.release.key-password; do
  if ! security find-generic-password \
    -a "MyTime Android Release" \
    -s "$service" \
    -w >/dev/null 2>&1; then
    echo "Missing Keychain item: $service" >&2
    exit 1
  fi
done

echo "Android release signing configuration is available locally."
