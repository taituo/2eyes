# Testing Manual for pair_stream Toolkit

This manual walks through validation of every supported feature in `pair_stream.sh` and its Python rotation backend. Execute the sections in order on a test host; reset the environment between scenarios if you need a clean slate.

## 1. Prerequisites
- Ensure `tmux`, `python3`, and `bash` are installed.
- Optional but recommended: install Apache `rotatelogs` to cover the dedicated backend.
- Place `pair_stream.sh` and `rotate.py` in a working directory, make sure both are executable (`chmod +x pair_stream.sh rotate.py`).
- Confirm `$HOME/pair/streams`, `$HOME/pair/out`, and `$HOME/pair/scripts` are writable (create them if needed).

## 2. Baseline Environment Reset
1. Stop any pre-existing session: `./pair_stream.sh stop --session pair || true`.
2. Delete old artefacts: `rm -rf ~/pair/streams ~/pair/out`.
3. Recreate base directories: `mkdir -p ~/pair/streams ~/pair/out ~/pair/scripts`.
4. Copy the current `rotate.py` into `~/pair/scripts/rotate.py`.

## 3. Core Lifecycle Commands
1. Start default session: `./pair_stream.sh start --mode basic --demo`.
2. In a new terminal, check status: `./pair_stream.sh status`.
   - Expect to see "Session 'pair' is running." and the generated `SPEC.md` path.
3. Attach to verify the tmux CLI pane is running the demo loop: `./pair_stream.sh attach` (detach with `Ctrl+b d`).
4. Stop the session: `./pair_stream.sh stop` and confirm `status` now reports "not running".

## 4. Mode Behaviour
### 4.1 Basic Mode
- Command: `./pair_stream.sh start --mode basic --demo`.
- Verify only the `CLI` window exists (`tmux list-windows -t pair`).
- Confirm stream files are written under `~/pair/streams` and `latest.log` points to the active chunk.
- Stop the session (`./pair_stream.sh stop`).

### 4.2 Split Mode
- Command: `./pair_stream.sh start --mode split --demo`.
- Attach and confirm two panes in the `VIEW` window: top `watch` listing and bottom `tail` following `latest.log`.
- Verify `CLI` output still rotates logs.
- Stop the session.

### 4.3 Advanced Mode
- Command: `./pair_stream.sh start --mode advanced --demo`.
- Confirm `VIEW` panes as in split mode.
- Confirm additional `CODEX` window appears:
  - Top pane runs `codex_reader.py` (log message in `~/pair/out/solutions.log`).
  - Bottom pane tails `solutions.log` continuously.
- Stop the session.

## 5. Backend Selection and Parity
### 5.1 Force rotatelogs Backend
1. Ensure `rotatelogs` exists (`command -v rotatelogs`).
2. Run: `./pair_stream.sh start --mode basic --demo -b rotatelogs`.
3. Inspect `~/pair/streams` to confirm filenames match `stream-YYYYMMDD-HHMM.log` with no suffixes.
4. Stop the session.

### 5.2 Force Python Backend
1. Run: `./pair_stream.sh start --mode basic --demo -b python`.
2. After a minute, confirm new chunk appears with canonical naming, no `_1` suffixes.
3. Restart the session immediately and verify the same file is reused (no suffix) while content appends.
4. Stop the session.

### 5.3 Auto Backend Fallback
1. Temporarily hide `rotatelogs` by launching via: `PATH="/nonexistent:$PATH" ./pair_stream.sh start --mode basic --demo -b auto`.
2. Confirm the script falls back to the Python backend (startup message shows `backend: python`).
3. Restore original PATH and stop the session.

## 6. Rotation Behaviour
1. Start with short interval: `./pair_stream.sh start --mode basic --demo --interval 10 --keep 3`.
2. Wait ~35 seconds.
3. Check `~/pair/streams`:
   - Expect only three `stream-*.log` files plus `latest.log`.
   - Confirm timestamps increment every 10 seconds.
4. Verify the `latest.log` symlink updates to the newest chunk (`readlink ~/pair/streams/latest.log`).
5. Stop the session.

## 7. Demo Mode When No Command Provided
1. Run: `./pair_stream.sh start --mode basic --session demo --cmd '' --demo`.
2. Attach to make sure the demo loop fills logs even without a custom `--cmd`.
3. Stop the `demo` session.

## 8. Error Handling Checks
1. Remove `~/pair/scripts/rotate.py` and attempt `./pair_stream.sh start -b python`.
   - Expect an error "rotate.py missing" and immediate exit.
2. Restore the script to proceed with other tests.
3. Attempt to start when the session already exists to ensure the script prints the friendly message and exits without error.

## 9. Cleanup Verification
- After all tests, run `./pair_stream.sh stop --session pair` and any other session names you used.
- Delete the test directories if desired: `rm -rf ~/pair/streams ~/pair/out ~/pair/scripts/codex_reader.py`.

Following this manual validates the tmux orchestration, mode layouts, backend parity, rotation guarantees, Codex integration, and resiliency paths described in the specification.
