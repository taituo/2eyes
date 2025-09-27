# SPEC Explanation

## Specification summary
- Streams are minute-sized chunks (`INTERVAL` seconds) stored under the configured stream directory.
- Chunks must follow the pattern `stream-YYYYMMDD-HHMM.log`; optionally a `latest.log` symlink points to the live chunk.
- Only the most recent `KEEP` chunks are retained; older ones are deleted.
- Both backends (`rotatelogs` and the Python fallback) are expected to produce identical naming and behaviour so that downstream agents (Codex, tailing tools) can rely on a consistent layout.

## Implementation notes
- `pair_stream.sh` (pair_stream.sh:1) wires up a tmux session and pipes CLI output into the selected backend. It also materialises `SPEC.md` inside the stream directory on startup so agents find the format description automatically.
- The shell script favours `rotatelogs` but falls back to `rotate.py` (pair_stream.sh:52-69) when Apache's tool is unavailable.
- The Python backend (`rotate.py`, rotate.py:1) watches stdin, rotates on `INTERVAL` boundaries, enforces the `KEEP` limit, and optionally refreshes the `latest.log` symlink with a relative link for portability.

## Identified issue
- `rotate.py` ensures uniqueness by appending suffixes (`_1`, `_2`, …) when the nominal chunk file already exists (rotate.py:23-26). This deviates from the spec requirement that both backends share identical naming; Apache `rotatelogs` never emits suffixed names. A restart within the same minute therefore yields files like `stream-20250101-1200_1.log`, breaking consumers that pattern-match `stream-*.log` without suffixes and undermining parity between backends.

## Suggested direction
- Instead of inventing suffixed names, the Python backend should reopen and append to the existing chunk for the current interval (or truncate/start fresh if that is acceptable) so that filenames remain authoritative and match the spec.
