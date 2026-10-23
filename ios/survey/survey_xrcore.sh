#!/usr/bin/env bash
# Survey: how far does xrCore get when compiled for iOS arm64 AS-IS (syntax check only)?
# It never links or runs anything. Missing headers are replaced by empty stubs so the compiler
# can keep going and show the next problem; every stub is reported in stubs.txt.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/survey_out"
SHIM="$OUT/shim"
LOGS="$OUT/logs"
rm -rf "$OUT"; mkdir -p "$SHIM" "$LOGS"
CXX="${SURVEY_CXX:-xcrun --sdk iphoneos clang++ -arch arm64 -miphoneos-version-min=16.0}"
VCX="$ROOT/src/xrCore/xrCore.vcxproj"

DEFS=(-DPURE_ALLOC -DNDEBUG -D_SECURE_SCL=0 -DXRCORE_EXPORTS)
INCS=(-I "$ROOT/src/xrCore" -I "$ROOT/src/3rd party" -I "$ROOT/src/3rd party/icu/include"
      -I "$ROOT/src/Include" -I "$ROOT/sdk/include" -I "$ROOT/sdk/include/dxsdk")

RES="$OUT/results.tsv"; STUBS="$OUT/stubs.txt"
: > "$RES"; : > "$STUBS"

FILES=$(grep -oE '<ClCompile Include="[^"]*"' "$VCX" | sed -E 's/.*Include="([^"]*)"/\1/; s#\\#/#g')

for f in $FILES; do
  src="$ROOT/src/xrCore/$f"
  if [ ! -f "$src" ]; then
    printf '%s\tMISSING\t0\t0\tfile not in repo\n' "$f" >> "$RES"; continue
  fi
  log="$LOGS/$(echo "$f" | tr '/' '_').log"
  fshim="$SHIM/$(echo "$f" | tr '/' '_')"; mkdir -p "$fshim"   # stubs are per file, so counts are honest
  tries=0
  while :; do
    $CXX -x c++ -std=c++17 -fsyntax-only -w -ferror-limit=0 "${DEFS[@]}" "${INCS[@]}" -I "$fshim" "$src" > "$log" 2>&1
    rc=$?
    hdr=$(grep -m1 -oE "fatal error: '[^']+' file not found" "$log" | sed -E "s/fatal error: '([^']+)'.*/\1/")
    if [ -n "$hdr" ] && [ "$tries" -lt 80 ]; then
      case "$hdr" in
        /*|*..*) echo "UNRESOLVABLE(path) $hdr <- $f" >> "$STUBS"; break ;;
      esac
      mkdir -p "$fshim/$(dirname "$hdr")"; : > "$fshim/$hdr"
      echo "$hdr <- $f" >> "$STUBS"
      tries=$((tries + 1)); continue
    fi
    break
  done
  n=$(grep -c ' error: ' "$log")
  first=$(grep -m1 ' error: ' "$log" | sed -E 's/^.*(error: .*)$/\1/' | cut -c1-140 | tr '|\t' '/ ')
  status=OK; [ "$rc" -ne 0 ] && status=FAIL
  printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$status" "$n" "$tries" "$first" >> "$RES"
done

{
  total=$(wc -l < "$RES" | tr -d ' ')
  ok=$(awk -F'\t' '$2=="OK"' "$RES" | wc -l | tr -d ' ')
  echo "## xrCore iOS arm64 compile survey (syntax-only, as-is, no Windows defines)"
  echo
  echo "Compiled cleanly: **$ok of $total** files. Toolchain: $($CXX --version 2>&1 | head -1)"
  echo
  echo "### Worst files (by error count)"
  echo "| file | status | errors | stubbed headers | first error |"
  echo "|---|---|---|---|---|"
  sort -t$'\t' -k3,3nr "$RES" | head -20 | awk -F'\t' '{printf "| %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5}'
  echo
  echo "### Headers that were missing and had to be stubbed (files affected)"
  echo '```'
  cut -d' ' -f1 "$STUBS" | sort | uniq -c | sort -rn | head -30
  echo '```'
  echo "### Most common errors"
  echo '```'
  cat "$LOGS"/*.log | grep ' error: ' | sed -E 's/^.* error: //' | cut -c1-110 | sort | uniq -c | sort -rn | head -15
  echo '```'
} > "$OUT/summary.md"

cat "$OUT/summary.md"
exit 0
