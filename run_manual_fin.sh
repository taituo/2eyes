#!/usr/bin/env bash
set -euo pipefail

# Jump to dev workspace and refresh the throwaway copy.
cd "${HOME}/dev"
rm -rf 2eyestest
cp -r 2eyes 2eyestest
cd 2eyestest

# Step 1: workspace setup exports and directories.
export PS_WORKDIR="$(pwd)/pair_test"
export STREAM_DIR="$PS_WORKDIR/streams"
export OUT_DIR="$PS_WORKDIR/out"
export SCRIPTS_DIR="$PS_WORKDIR/scripts"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
chmod +x pair_stream.sh "$SCRIPTS_DIR/rotate.py"

# Step 2: reset before running scenarios.
./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"

# Print the Finnish manual for the remaining steps.
cat manual_fin.md

cat <<'MSG'

-- Environment prepared. You are now in ~/dev/2eyestest.
-- Continue by running the command blocks from the manual above.
MSG

# Drop into an interactive shell that retains the exported variables.
exec bash --noprofile --norc
