#!/usr/bin/env bash
# Fetch an open standard-cell liberty for the open-source timing flow.
#
# Downloads the Nangate45 (45 nm, typical corner) library used by `synth` to
# produce a real nanosecond critical-path/FMax estimate. It is a text data file
# read by yosys/ABC; nothing from it is executed.
#
# To use a different library instead, drop any *.lib in this stdcells/ directory
# or point the STDCELL_LIB environment variable at it.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/stdcells"
URL="https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD/master/test/Nangate45/Nangate45_typ.lib"
OUT="$DIR/Nangate45_typ.lib"

mkdir -p "$DIR"
echo "Fetching Nangate45 liberty -> $OUT"
curl -fL -o "$OUT" "$URL"
echo "Done ($(wc -c < "$OUT") bytes). 'synth' will now report standard-cell timing."
