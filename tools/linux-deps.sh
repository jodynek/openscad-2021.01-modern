#!/usr/bin/env bash
# Installs (or just lists, with --check) the build dependencies for Ubuntu 24.04 / Debian 12+.
#   sudo ./tools/linux-deps.sh            # install everything (headless + GUI)
#   ./tools/linux-deps.sh --check         # show which packages are available / installed
#   sudo ./tools/linux-deps.sh --headless # command-line build only (no Qt)
set -euo pipefail

CORE=(
  build-essential cmake ninja-build pkg-config git flex bison
  libcgal-dev libgmp-dev libmpfr-dev
  libboost-program-options-dev libboost-dev
  libeigen3-dev libglew-dev libopencsg-dev libglu1-mesa-dev libgl1-mesa-dev libx11-dev
  libharfbuzz-dev libfontconfig-dev libfreetype-dev
  libzip-dev libxml2-dev libcairo2-dev libdouble-conversion-dev
  lib3mf-dev
)
GUI=(
  qt6-base-dev qt6-base-dev-tools qt6-multimedia-dev qt6-svg-dev
  libqscintilla2-qt6-dev
)

mode="install"
case "${1:-}" in
  --check) mode="check" ;;
  --headless) GUI=() ;;
  "") ;;
  *) echo "usage: $0 [--check|--headless]" >&2; exit 2 ;;
esac

PKGS=("${CORE[@]}" "${GUI[@]}")

if [[ "$mode" == "check" ]]; then
  printf '%-32s %-14s %s\n' PACKAGE INSTALLED CANDIDATE
  for p in "${PKGS[@]}"; do
    inst=$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null || echo "-")
    cand=$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/ {print $2}')
    printf '%-32s %-14s %s\n' "$p" "${inst:--}" "${cand:-(not available)}"
  done
  exit 0
fi

apt-get update
apt-get install -y --no-install-recommends "${PKGS[@]}"
