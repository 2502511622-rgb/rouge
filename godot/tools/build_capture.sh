#!/bin/sh
# Build the read-only ROM observation frontend. mGBA source remains unmodified.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${MGBA_SOURCE:?Set MGBA_SOURCE to mGBA tag 0.10.5 (commit 26b7884bc25a5933960f3cdcd98bac1ae14d42e2)}"
: "${MGBA_BUILD:?Set MGBA_BUILD to its configured build directory}"
cc -std=c11 -D_GNU_SOURCE -DUSE_DEBUGGERS -DM_CORE_GBA \
  -I"$MGBA_SOURCE/include" -I"$MGBA_BUILD/include" \
  "$project_dir/tools/gba_capture.c" -L"$MGBA_BUILD" \
  -Wl,-rpath,"$MGBA_BUILD" -lmgba -o "$project_dir/tools/gba_capture"
