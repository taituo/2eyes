#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'HELP'
Usage: manual_test.sh [--source PATH] [--target PATH] [--manual PATH]

Copies the project from the source directory to the target directory, runs the
setup + reset steps from the manuals, and prints the chosen manual. Drops into
an interactive shell inside the target with environment variables exported.

Options:
  --source PATH   Path to the canonical repo (default: directory of this script)
  --target PATH   Directory for the working copy  (default: $HOME/dev/2eyestest)
  --manual PATH   Manual file to display        (default: manual.md)
HELP
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE="$SCRIPT_DIR"
DEFAULT_TARGET="$HOME/dev/2eyestest"

SOURCE=""
TARGET=""
MANUAL="manual.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --manual) MANUAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

SOURCE="${SOURCE:-$DEFAULT_SOURCE}"
TARGET="${TARGET:-$DEFAULT_TARGET}"

if [[ "$SOURCE" == "$TARGET" ]]; then
  echo "Source and target must differ." >&2
  exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
  echo "Source '$SOURCE' not found." >&2
  exit 1
fi
[[ -f "$SOURCE/pair_stream.sh" ]] || { echo "Source missing pair_stream.sh." >&2; exit 1; }
[[ -f "$SOURCE/rotate.py" ]] || { echo "Source missing rotate.py." >&2; exit 1; }

case "$MANUAL" in
  /*) MANUAL_PATH="$MANUAL" ;;
  *)  MANUAL_PATH="$SOURCE/$MANUAL" ;;
esac

if [[ ! -f "$MANUAL_PATH" ]]; then
  echo "Manual '$MANUAL_PATH' not found." >&2
  exit 1
fi

TARGET_PARENT="$(dirname "$TARGET")"
mkdir -p "$TARGET_PARENT"

rm -rf "$TARGET"
cp -r "$SOURCE" "$TARGET"
cd "$TARGET"

export PS_WORKDIR="$(pwd)/pair_test"
export STREAM_DIR="$PS_WORKDIR/streams"
export OUT_DIR="$PS_WORKDIR/out"
export SCRIPTS_DIR="$PS_WORKDIR/scripts"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"
chmod +x pair_stream.sh "$SCRIPTS_DIR/rotate.py"

./pair_stream.sh stop --session pair || true
rm -rf "$STREAM_DIR" "$OUT_DIR"
mkdir -p "$STREAM_DIR" "$OUT_DIR" "$SCRIPTS_DIR"
cp rotate.py "$SCRIPTS_DIR/rotate.py"

cat "$MANUAL_PATH"

cat <<EOF

-- Environment prepared. You are now in $TARGET.
-- Continue by running the command blocks from $(basename "$MANUAL_PATH") above.
