#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app_json="AppScope/app.json5"
module_json="entry/src/main/module.json5"
hap_path="entry/build/default/outputs/default/entry-default-unsigned.hap"
app_path="build/outputs/default/YueJiPC-default-unsigned.app"
packed_hap_path="entry/build/default/outputs/default/app/entry-default.hap"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq '"bundleName": "com.huihui.yueji"' "$app_json" ||
  fail "bundleName is not com.huihui.yueji"
grep -Fq '"versionCode": 1000000' "$app_json" ||
  fail "versionCode is not 1000000"
grep -Fq '"versionName": "1.0.0"' "$app_json" ||
  fail "versionName is not 1.0.0"
grep -Fq '"deviceTypes": [' "$module_json" ||
  fail "module deviceTypes are missing"
grep -Fq '"2in1"' "$module_json" ||
  fail "module does not target 2in1"

[ -f "$hap_path" ] || fail "missing HAP: $hap_path"
[ -f "$app_path" ] || fail "missing APP: $app_path"
[ -f "$packed_hap_path" ] || fail "missing packed HAP: $packed_hap_path"

module_info="$(mktemp)"
trap 'rm -f "$module_info"' EXIT
unzip -p "$hap_path" module.json > "$module_info" 2>/dev/null ||
  fail "cannot read module.json from HAP"

grep -Fq '"debug":false' "$module_info" ||
  fail "HAP is not marked debug:false"
grep -Fq '"buildMode":"release"' "$module_info" ||
  fail "HAP is not marked buildMode:release"
grep -Fq '"bundleName":"com.huihui.yueji"' "$module_info" ||
  fail "HAP bundleName is unexpected"
grep -Fq '"versionName":"1.0.0"' "$module_info" ||
  fail "HAP versionName is unexpected"
grep -Fq '"versionCode":1000000' "$module_info" ||
  fail "HAP versionCode is unexpected"

printf 'Release audit passed\n'
printf 'Bundle: com.huihui.yueji\n'
printf 'Version: 1.0.0 (1000000)\n'
printf 'Target: HarmonyOS 6.1.1 / API 24 / 2in1\n'
printf 'HAP: %s (%s bytes) SHA-256 %s\n' \
  "$hap_path" "$(stat -f '%z' "$hap_path")" "$(shasum -a 256 "$hap_path" | awk '{print $1}')"
printf 'APP: %s (%s bytes) SHA-256 %s\n' \
  "$app_path" "$(stat -f '%z' "$app_path")" "$(shasum -a 256 "$app_path" | awk '{print $1}')"
printf 'Packed HAP: %s (%s bytes) SHA-256 %s\n' \
  "$packed_hap_path" "$(stat -f '%z' "$packed_hap_path")" "$(shasum -a 256 "$packed_hap_path" | awk '{print $1}')"
