#!/usr/bin/env bash
# 用法: package-release-apk.sh <tag> [build-number]
#
# 解析 semver tag → 构建签名 release APK → 产出:
#   release/mytime-<tag>.apk
#   release/mytime-<tag>.apk.sha256
#
# tag 需形如 v1.2.3 / v1.2.3+N / v1.2.3-rc.1;build-number 需为纯数字,
# 未传或非法时回退到 tag 中的 +N,否则报错。

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tag="${1:?usage: package-release-apk.sh <tag> [build-number]}"

if [[ ! "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z]+)*$ ]]; then
  echo "Tag '$tag' does not look like a version (expected e.g. v1.2.3, v1.2.3+N, v1.2.3-rc.1)." >&2
  exit 1
fi

build_number="${2:-}"
if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
  build_number=""
  if [[ "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$ ]]; then
    build_number="${BASH_REMATCH[1]}"
  fi
fi
if [[ -z "$build_number" ]]; then
  echo "No numeric build number: pass it as the 2nd argument or embed it in the tag as v1.2.3+N." >&2
  exit 1
fi

version="${tag#v}"
version="${version%%+*}" # build-name 不含 +N,build-number 单独传

"$project_root/scripts/build-release-apk.sh" --build-name "$version" --build-number "$build_number"

apk=""
for candidate in \
  "build/app/outputs/apk/release/app-release.apk" \
  "build/app/outputs/flutter-apk/app-release.apk"; do
  if [[ -f "$project_root/$candidate" ]]; then
    apk="$candidate"
    break
  fi
done

if [[ -z "$apk" ]]; then
  echo "Release APK was not produced." >&2
  exit 1
fi

mkdir -p "$project_root/release"
cp "$project_root/$apk" "$project_root/release/mytime-${tag}.apk"
(cd "$project_root/release" && sha256sum "mytime-${tag}.apk" > "mytime-${tag}.apk.sha256")
echo "Packaged release/mytime-${tag}.apk"
