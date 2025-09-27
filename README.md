# 2eyes Toolkit

A lightweight tmux-based pairing environment for collecting CLI output into time-sliced streams and feeding it to an advisor agent. It bundles:

- `pair_stream.sh` — orchestrates tmux panes/windows, runs your command, and streams output into rotatelogs or the Python fallback.
- `rotate.py` — Python backend implementing the same rotation behaviour as Apache `rotatelogs` with interval-accurate filenames.
- `manual_test.sh` — helper that spins up a disposable workspace, prints the runnable manuals, and optionally cleans up after testing.
- Manuals (`manual.md`, `manual_fin.md`) and `SPEC_explanation.md` describing the stream format and testing flow.

## Implemented

- **Panel-first layout:** default tmux session launches with `CLI Panel`, `Streams Panel`, and (in advanced mode) `Advisor Panel`, each with titled panes so you always work inside panels.
- **Backend parity:** Python rotation keeps canonical filenames; symlink/local cleanup mirrors `rotatelogs`.
- **Workspace helper:** `manual_test.sh` clones the repo to `<source>_test`, exports needed env vars, and runs your login shell; `--clean` removes the sandbox on exit.
- **Manuals as code blocks:** English and Finnish guides are single copy/paste blocks covering setup, lifecycle, modes, backends, rotation, error paths, and cleanup.
- **Spec surfaced in runtime:** `pair_stream.sh` writes `SPEC.md` into the stream directory on each start so agents can read the stream specification inline.

## Not Yet Implemented / TODO

- **Automated tests:** manuals describe manual validation; there’s no automated test harness yet.
- **Dependency auto-installation:** script exits if `tmux`, `rotatelogs`, or `rotate.py` prerequisites are missing; no installer or package manager integration.
- **Codex advisor enhancements:** generated `codex_reader.py` ships with baseline rules; no extensibility or plugin system beyond editing the script.
- **Cross-platform validation:** tested on Linux tmux environments; no Windows/WSL adjustments in place.
- **CI pipeline:** repository doesn’t include GitHub Actions or other CI definitions yet.

## Getting Started

```bash
git clone git@github.com:taituo/2eyes.git
cd 2eyes
./manual_test.sh --manual manual.md --clean
```

The helper will clone into `../2eyes_test`, run setup/reset, print the manual, and drop you into the prepared shell. Follow the code block to exercise every feature. Use `--manual manual_fin.md` for Finnish instructions.

## Contributing

1. Fork the repo, create a branch, and align with the manuals (ensure no suffixed chunk filenames, panels correctly named).
2. If you update the stream spec or scripts, mirror the change in both manuals.
3. Run through `manual_test.sh --clean` to confirm the flow remains intact.
4. Submit a PR detailing implemented features vs planned TODOs.

