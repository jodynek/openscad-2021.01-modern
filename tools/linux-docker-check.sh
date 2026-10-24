#!/usr/bin/env bash
# Builds and smoke-tests OpenSCAD inside a clean Ubuntu 24.04 container.
# Nothing is installed on the host; only Docker is needed. Useful on Windows (Docker Desktop)
# to verify the Linux build, and as the reference for CI.
#
#   tools/linux-docker-check.sh                # headless + GUI build, smoke run
#   tools/linux-docker-check.sh --headless     # command-line build only
#   JOBS=8 tools/linux-docker-check.sh         # parallel compile jobs (default 4: a CGAL
#                                              #   translation unit needs ~1 GB, the Docker
#                                              #   Desktop VM usually has 8 GB)
#
# Output (binaries, logs, echo results) ends up in ./build/linux-docker on the host.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
JOBS="${JOBS:-4}"
OUT="$SRC/build/linux-docker"
mkdir -p "$OUT"

# Docker Desktop on Windows needs a drive-letter path for the bind mount
host_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

docker run --rm \
  -v "$(host_path "$SRC"):/src:ro" \
  -v "$(host_path "$OUT"):/out" \
  -e MODE="$MODE" -e JOBS="$JOBS" \
  ubuntu:24.04 bash -c '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "### installing packages"
apt-get update -qq
apt-get install -y -qq --no-install-recommends ca-certificates > /dev/null
cp -r /src /work
cd /work
if [ "$MODE" = "--headless" ]; then bash tools/linux-deps.sh --headless > /out/apt.log 2>&1; else bash tools/linux-deps.sh > /out/apt.log 2>&1; fi

echo "### configure + build: linux-headless (jobs: $JOBS)"
rm -rf build
cmake --preset linux-headless > /out/configure-headless.log 2>&1 || { tail -40 /out/configure-headless.log; exit 1; }
cmake --build --preset linux-headless --parallel "$JOBS" -- -k 0 > /out/build-headless.log 2>&1 || { grep -E "error|Error" /out/build-headless.log | head -40; exit 1; }

echo "### smoke (headless)"
B=/work/build/linux-headless
$B/openscad --version
cd tests/smoke
FAILED=0
for t in lang utf8 esc main; do
  $B/openscad -o /out/$t.echo $t.scad 2>/dev/null || true
  if cmp -s <(tr -d "\r" < expected/$t.echo) <(tr -d "\r" < /out/$t.echo); then
    echo "PASS $t.scad"
  else
    echo "FAIL $t.scad"; FAILED=1
    diff <(tr -d "\r" < expected/$t.echo) <(tr -d "\r" < /out/$t.echo) | head -6 || true
  fi
done
for f in "../../examples/Basics/logo.scad:5892" "tetra.scad:4"; do
  scad="${f%%:*}"; want="${f##*:}"
  got=$($B/openscad -o /out/geom.stl "$scad" 2>&1 | sed -n "s/^ *Facets: *\([0-9]*\).*/\1/p")
  if [ "$got" = "$want" ]; then echo "PASS $scad ($got facets)"; else echo "FAIL $scad (facets: $got, expected $want)"; FAILED=1; fi
done
cd /work
cp $B/openscad /out/openscad-headless

if [ "$MODE" != "--headless" ]; then
  echo "### configure + build: linux-release (GUI)"
  cmake --preset linux-release > /out/configure-gui.log 2>&1 || { tail -40 /out/configure-gui.log; exit 1; }
  cmake --build --preset linux-release --parallel "$JOBS" -- -k 0 > /out/build-gui.log 2>&1 || { grep -E "error|Error" /out/build-gui.log | head -40; exit 1; }
  cp build/linux-release/openscad /out/openscad-gui
  echo "### GUI binary built: $(stat -c %s build/linux-release/openscad) bytes"
fi
[ "$FAILED" = 0 ] || { echo "### smoke tests FAILED"; exit 1; }
echo "### done"
'
