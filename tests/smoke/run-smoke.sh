#!/usr/bin/env bash
# Linux counterpart of run-smoke.ps1: echo-output comparison and facet counts for the
# command-line build. Usage: tests/smoke/run-smoke.sh [path/to/openscad] (default: build/linux-headless/openscad)
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
EXE="${1:-$DIR/../../build/linux-headless/openscad}"
EXE="$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$DIR"
FAILED=0
"$EXE" --version
for t in lang utf8 esc main; do
  "$EXE" -o "$TMP/$t.echo" "$t.scad" 2>/dev/null || true
  if cmp -s <(tr -d '\r' < "expected/$t.echo") <(tr -d '\r' < "$TMP/$t.echo" 2>/dev/null); then
    echo "PASS $t.scad"
  else
    echo "FAIL $t.scad"; FAILED=1
    diff <(tr -d '\r' < "expected/$t.echo") <(tr -d '\r' < "$TMP/$t.echo" 2>/dev/null) | head -6 || true
  fi
done
for f in "../../examples/Basics/logo.scad:5892" "tetra.scad:4" "main.scad:222"; do
  scad="${f%%:*}"; want="${f##*:}"
  got=$("$EXE" -o "$TMP/geom.stl" "$scad" 2>&1 | sed -n 's/^ *Facets: *\([0-9]*\).*/\1/p')
  if [ "$got" = "$want" ]; then echo "PASS $scad ($got facets)"; else echo "FAIL $scad (facets: ${got:-none}, expected $want)"; FAILED=1; fi
done
if [ "$FAILED" = 0 ]; then echo "ALL SMOKE TESTS PASSED"; else echo "SMOKE TESTS FAILED"; fi
exit $FAILED
