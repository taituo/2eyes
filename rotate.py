#!/usr/bin/env python3
import sys, os, time, argparse, glob


def parse_args():
    ap = argparse.ArgumentParser(description="Time-based log splitter (stdin -> chunks).")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--keep", type=int, default=60)
    ap.add_argument("--latest", default="")
    return ap.parse_args()


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def chunk_name(outdir, timestamp=None):
    timestamp = timestamp or time.time()
    return os.path.join(outdir, time.strftime("stream-%Y%m%d-%H%M.log", time.localtime(timestamp)))


def rotate_cleanup(outdir, keep):
    files = sorted(glob.glob(os.path.join(outdir, "stream-*.log")))
    excess = max(0, len(files) - keep)
    for path in files[:excess]:
        try:
            os.remove(path)
        except OSError:
            pass


def update_latest(outdir, latest, target):
    if not latest:
        return
    link = os.path.join(outdir, latest)
    try:
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(os.path.relpath(target, outdir), link)
    except Exception:
        try:
            import shutil
            shutil.copy2(target, link)
        except Exception:
            pass


def main():
    args = parse_args()
    ensure_dir(args.outdir)
    current_file = None
    end_ts = 0

    def open_chunk(now=None):
        nonlocal current_file, end_ts
        now = now or time.time()
        path = chunk_name(args.outdir, now)
        current_file = open(path, "a", buffering=1)
        window_start = int(now // args.interval) * args.interval
        end_ts = window_start + args.interval
        update_latest(args.outdir, args.latest, path)
        rotate_cleanup(args.outdir, args.keep)
        return current_file

    current_file = open_chunk()

    try:
        for line in sys.stdin:
            now = time.time()
            if now >= end_ts:
                try:
                    current_file.flush()
                    current_file.close()
                except Exception:
                    pass
                current_file = open_chunk(now)
            current_file.write(line)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            current_file.flush()
            current_file.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()

