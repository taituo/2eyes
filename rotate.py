#!/usr/bin/env python3
import sys, os, time, argparse, glob

def parse_args():
    ap = argparse.ArgumentParser(description="Time-based log splitter (stdin -> chunks).")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--keep", type=int, default=60)
    ap.add_argument("--latest", default="")
    return ap.parse_args()

def ensure_dir(p): os.makedirs(p, exist_ok=True)
def chunk_name(outdir, t=None):
    t = t or time.time()
    return os.path.join(outdir, time.strftime("stream-%Y%m%d-%H%M.log", time.localtime(t)))
def rotate_cleanup(outdir, keep):
    files = sorted(glob.glob(os.path.join(outdir, "stream-*.log")))
    for f in files[:max(0, len(files)-keep)]:
        try: os.remove(f)
        except OSError: pass
def update_latest(outdir, latest, target):
    if not latest: return
    link = os.path.join(outdir, latest)
    try:
        if os.path.lexists(link): os.remove(link)
        os.symlink(os.path.relpath(target, outdir), link)
    except Exception:
        try:
            import shutil; shutil.copy2(target, link)
        except Exception: pass

def main():
    a = parse_args(); ensure_dir(a.outdir)
    cur, end_ts = None, 0
    def open_new(now=None):
        nonlocal cur, end_ts
        now = now or time.time()
        path = chunk_name(a.outdir, now)
        base, ext = os.path.splitext(path); i=1
        while os.path.exists(path): path=f"{base}_{i}{ext}"; i+=1
        cur = open(path, "a", buffering=1)
        end_ts = int(now//a.interval)*a.interval + a.interval
        update_latest(a.outdir, a.latest, path); rotate_cleanup(a.outdir, a.keep)
        return cur
    f = open_new()
    try:
        for line in sys.stdin:
            now = time.time()
            if now >= end_ts:
                try: f.flush(); f.close()
                except Exception: pass
                f = open_new(now)
            f.write(line)
    except KeyboardInterrupt:
        pass
    finally:
        try: f.flush(); f.close()
        except Exception: pass

if __name__ == "__main__":
    main()

