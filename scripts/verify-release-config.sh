#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
properties_file="$project_root/android/key.properties"

# CI 模式:签名材料由环境变量注入(GitHub Actions / CNB secrets)。
env_keystore="${ANDROID_KEYSTORE_FILE:-}"
env_store_pw="${ANDROID_KEYSTORE_PASSWORD:-}"
env_key_pw="${ANDROID_KEY_PASSWORD:-}"
env_alias="${ANDROID_KEY_ALIAS:-}"

if [[ -n "$env_keystore" || -n "$env_store_pw" || -n "$env_key_pw" || -n "$env_alias" ]]; then
  missing=""
  [[ -n "$env_keystore" ]] || missing="$missing ANDROID_KEYSTORE_FILE"
  [[ -n "$env_store_pw" ]] || missing="$missing ANDROID_KEYSTORE_PASSWORD"
  [[ -n "$env_key_pw" ]] || missing="$missing ANDROID_KEY_PASSWORD"
  [[ -n "$env_alias" ]] || missing="$missing ANDROID_KEY_ALIAS"
  if [[ -n "$missing" ]]; then
    echo "Missing Android signing environment variables:$missing" >&2
    echo "Configure them as CI secrets (GitHub Actions / CNB variables)." >&2
    exit 1
  fi
  if [[ ! -f "$env_keystore" ]]; then
    echo "The Android keystore does not exist: $env_keystore" >&2
    exit 1
  fi
  echo "Android release signing configuration is available via environment."
  exit 0
fi

# 本地 macOS 模式:key.properties + Keychain。
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

if ! command -v security >/dev/null 2>&1; then
  echo "No 'security' binary (macOS Keychain unavailable)." >&2
  echo "On CI, set ANDROID_KEYSTORE_FILE/ANDROID_KEYSTORE_PASSWORD/ANDROID_KEY_PASSWORD/ANDROID_KEY_ALIAS." >&2
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
