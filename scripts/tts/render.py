"""Pre-renders every spoken line in Content/ with Kokoro-82M (local, Apache-2.0) into the app's
audio cache as <sha256>.m4a, so listening plays a neural voice instead of the system TTS.

Incremental: lines whose file already exists are skipped, so it can be stopped and restarted.
Files appear atomically (rendered and converted in <cache>/.tmp, then renamed).

    cd scripts/tts
    uv run python render.py                       # everything missing, into the Debug (TenazDev) cache
    uv run python render.py --limit 30            # quick test
    uv run python render.py --cache ~/Library/Application\\ Support/Tenaz/audio-cache   # Release build

Model files (from github.com/thewh1teagle/kokoro-onnx releases, model-files-v1.0) are read from
$TENAZ_KOKORO_DIR (default ~/.cache/tenaz/kokoro/) and downloaded there if missing.
"""

import argparse
import json
import multiprocessing as mp
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import cast

MODEL_DIR = Path(os.environ.get("TENAZ_KOKORO_DIR", Path.home() / ".cache" / "tenaz" / "kokoro")).expanduser()
MODEL_FILES = ("kokoro-v1.0.onnx", "voices-v1.0.bin")
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
DEFAULT_CACHE = Path.home() / "Library" / "Application Support" / "TenazDev" / "audio-cache"


def ensure_model():
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    for name in MODEL_FILES:
        path = MODEL_DIR / name
        if not path.exists():
            print(f"downloading {name}…", flush=True)
            tmp = path.with_suffix(path.suffix + ".part")
            urllib.request.urlretrieve(MODEL_URL + name, tmp)
            tmp.replace(path)


def collect_jobs(content):
    """Unique (key, voice, text) for every line the app speaks, plus the total line count."""
    jobs, total = {}, 0
    for f in sorted((content / "items").glob("*.json")):
        for item in json.loads(f.read_text(encoding="utf-8")):
            for group in cast.spoken_groups(item):
                for voice, ln in zip(cast.voices(group), group):
                    total += 1
                    if ln["text"].strip():
                        jobs.setdefault(cast.cache_key(voice, ln["text"]), (voice, ln["text"]))
    return [(k, v, t) for k, (v, t) in jobs.items()], total


_kokoro = None


def init_worker(threads):
    global _kokoro
    import onnxruntime as rt
    from kokoro_onnx import Kokoro

    opts = rt.SessionOptions()
    opts.intra_op_num_threads = threads
    opts.inter_op_num_threads = 1
    session = rt.InferenceSession(str(MODEL_DIR / MODEL_FILES[0]), sess_options=opts,
                                  providers=["CPUExecutionProvider"])
    _kokoro = Kokoro.from_session(session, str(MODEL_DIR / MODEL_FILES[1]))


def render(job, cache):
    import soundfile as sf

    key, voice, text = job
    tmp = cache / ".tmp"
    wav, m4a = tmp / f"{key}.wav", tmp / f"{key}.m4a"
    start = time.monotonic()
    try:
        samples, rate = _kokoro.create(text, voice=voice, speed=float(cast.SPEED), lang=cast.lang(voice))
        sf.write(wav, samples, rate)
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", str(wav), str(m4a)],
                       check=True, capture_output=True)
        m4a.replace(cache / f"{key}.m4a")
        return key, voice, len(samples) / rate, time.monotonic() - start, None
    except Exception as e:  # one bad line must not stop a multi-hour run
        return key, voice, 0.0, time.monotonic() - start, repr(e)
    finally:
        wav.unlink(missing_ok=True)
        m4a.unlink(missing_ok=True)


def _render_star(args):
    return render(*args)


def main():
    cores = os.cpu_count() or 2
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--cache", type=Path, default=DEFAULT_CACHE, help=f"audio cache folder (default {DEFAULT_CACHE})")
    p.add_argument("--content", type=Path, default=cast.ROOT / "Content")
    p.add_argument("--limit", type=int, default=None, help="render at most N missing lines")
    p.add_argument("--workers", type=int, default=max(1, cores // 2), help="worker processes (default cores/2)")
    p.add_argument("--threads", type=int, default=2, help="onnxruntime threads per worker (default 2)")
    a = p.parse_args()

    cache = a.cache.expanduser()
    (cache / ".tmp").mkdir(parents=True, exist_ok=True)
    jobs, total = collect_jobs(a.content)
    pending = [j for j in jobs if not (cache / f"{j[0]}.m4a").exists()]
    print(f"{total} spoken lines, {len(jobs)} unique, {len(jobs) - len(pending)} cached, {len(pending)} to render "
          f"→ {cache}", flush=True)
    if a.limit is not None:
        pending = pending[: a.limit]
    if not pending:
        return 0
    ensure_model()

    print(f"rendering {len(pending)} with {a.workers} workers × {a.threads} threads", flush=True)
    start, audio, failed = time.monotonic(), 0.0, 0
    ctx = mp.get_context("spawn")
    with ctx.Pool(a.workers, initializer=init_worker, initargs=(a.threads,)) as pool:
        for i, (key, voice, seconds, took, err) in enumerate(
                pool.imap_unordered(_render_star, [(j, cache) for j in pending]), 1):
            elapsed = time.monotonic() - start
            eta = elapsed / i * (len(pending) - i)
            if err:
                failed += 1
                print(f"[{i}/{len(pending)}] FAILED {key[:12]} {voice}: {err}", flush=True)
            else:
                audio += seconds
                print(f"[{i}/{len(pending)}] {key[:12]} {voice:<12} {seconds:5.1f}s audio in {took:4.1f}s · "
                      f"eta {eta / 60:.0f} min", flush=True)
    elapsed = time.monotonic() - start
    print(f"done: {len(pending) - failed} files, {audio / 60:.1f} min of audio in {elapsed / 60:.1f} min"
          f" ({audio / max(elapsed, 0.001):.1f}× real time), {failed} failed", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
