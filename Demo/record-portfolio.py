#!/usr/bin/env python3
"""Records Quip's portfolio clips with the Cap CLI, from the DEBUG demo harness.

Each clip runs a scripted scene in the harness's fixed-size stage window
(QUIP_DEMO_STAGE=1, 1280x800 pt), which Cap records by window id at 60 fps. The
window never changes size, so a popover that resizes inside it is filmed exactly.

A clip is two takes of the same deterministic scene: one on white (exported as
the readme and social versions) and one on warm grey (the website version), the
backgrounds the Chorus clips use. Outputs are trimmed to the scene, from the
director's go signal to its SCENE_DONE.

Usage:
  Demo/record-portfolio.py take <clip>       # both takes and all three exports
  Demo/record-portfolio.py check <take-dir>  # stills and contact sheets again
  clips: 1-collections, 2-copy, 3-sizes

Local only. Nothing here uploads; never call `cap upload`.
"""
import datetime as dt
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/dd-demo/Build/Products/Debug/Quip.app/Contents/MacOS/Quip"
PROC = "build/dd-demo/Build/Products/Debug/Quip.app"   # pkill pattern: never the installed Quip
ASSETS = ROOT / "Demo/assets"
LIBRARY = ASSETS / "library"
CAP = Path.home() / ".local/bin/cap"
OUT = ROOT / "Demo/clips/portfolio" / dt.date.today().isoformat()

WHITE, GREY = "FFFFFF", "ECE9E4"   # Chorus readme/social and website backgrounds
STAGE_W, STAGE_H = 1280, 800        # points; the capture is 2x
SQUARE = 800                        # social crop, points, centred on the popover

CLIPS = {
    "1-collections": {"scene": "p-collections", "layout": "tall",
                      "env": {"QUIP_DEMO_COLLECTION": "shocked", "QUIP_DEMO_QUERY": "shocked"}},
    "2-copy": {"scene": "p-copy", "layout": "tall", "env": {"QUIP_DEMO_QUERY": "celebrate"}},
    "3-sizes": {"scene": "p-layout", "layout": "narrow", "env": {}},
}

PRESETS = {   # name: (take background, width, height)
    "readme": (WHITE, 1920, 1200),
    "website": (GREY, 2560, 1600),
    "social": (WHITE, 1080, 1080),
}


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def sh(*args):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True, text=True).stdout


def kill_demo():
    subprocess.run(["pkill", "-f", PROC], capture_output=True)
    for _ in range(25):
        if subprocess.run(["pgrep", "-f", PROC], capture_output=True).returncode:
            return
        time.sleep(0.2)


def wait_for(log_path, token, timeout):
    end = time.time() + timeout
    while time.time() < end:
        text = log_path.read_text(errors="replace") if log_path.exists() else ""
        for line in text.splitlines():
            if line.startswith(token):
                return line[len(token):].strip("=").strip() or True
        time.sleep(0.05)
    return None


def record(clip_name, background, take_dir):
    """One take of the clip's scene on one background. Returns the take's timings."""
    clip = CLIPS[clip_name]
    take_dir.mkdir(parents=True, exist_ok=True)
    demo_log, go = take_dir / "demo.log", take_dir / "go"
    project = take_dir / "take.cap"
    kill_demo()
    env = {**os.environ, "QUIP_DEMO": "1", "QUIP_DEMO_STAGE": "1", "QUIP_DEMO_BG": background,
           "QUIP_DEMO_SCENE": clip["scene"], "QUIP_DEMO_LAYOUT": clip["layout"],
           "QUIP_DEMO_GO": str(go), "QUIP_DEMO_ASSETS": str(ASSETS),
           "QUIP_DEMO_LIBRARY": str(LIBRARY), **clip["env"]}
    with open(demo_log, "w") as out:
        app = subprocess.Popen([str(APP)], env=env, stdout=out, stderr=subprocess.STDOUT, cwd=ROOT)
    try:
        wid = wait_for(demo_log, "DEMO_WINDOW_ID", 15)
        if not wid:
            sys.exit("the demo window never appeared")
        time.sleep(2.5)   # every GIF loads before the camera rolls
        sh(CAP, "record", "start", "--window", wid, "--fps", 60, "--detach", "--path", project, "--json")
        t0 = time.time()
        time.sleep(0.8)
        go.touch()
        t_go = time.time() - t0
        if not wait_for(demo_log, "SCENE_DONE", 60):
            sys.exit("the scene never finished")
        t_done = time.time() - t0
        time.sleep(0.4)
        sh(CAP, "record", "stop", "--path", project, "--json")
    finally:
        app.send_signal(signal.SIGTERM)
        kill_demo()
    meta = json.loads((project / "recording-meta.json").read_text())
    offset = meta["segments"][0]["display"].get("start_time", 0.25)
    info = {"clip": clip_name, "background": background, "window_id": wid,
            "go": round(t_go, 3), "done": round(t_done, 3), "video_offset": offset}
    (take_dir / "take.json").write_text(json.dumps(info, indent=2))
    log(f"{clip_name} on #{background}: scene {t_done - t_go:.1f} s")
    return info


def styled(project, preset, dest):
    """A clone of the Cap project set up for one preset: no Cap cursor (the scene
    draws its own), no padding or frame (the stage is the frame), and for social a
    square crop centred on the popover."""
    if dest.exists():
        shutil.rmtree(dest)
    sh("/bin/cp", "-c", "-R", project, dest)   # an APFS clone
    cfg_path = dest / "project-config.json"
    cfg = json.loads(cfg_path.read_text())
    cfg["cursor"].update({"hide": True, "hideWhenIdle": False})
    cfg["timeline"]["zoomSegments"] = []
    cfg["aspectRatio"] = None
    bg = cfg["background"]
    bg.update({"padding": 0.0, "rounding": 0.0, "shadow": 0.0, "inset": 0, "crop": None,
               "source": {"type": "color", "value": [255, 255, 255], "alpha": 255}})
    if preset == "social":
        x = (STAGE_W - SQUARE) // 2
        bg["crop"] = {"position": {"x": x * 2, "y": 0}, "size": {"x": SQUARE * 2, "y": SQUARE * 2}}
        cfg["aspectRatio"] = "square"
    cfg_path.write_text(json.dumps(cfg, indent=2))
    return dest


def export(take_dir, info, preset, clip_name, out_dir):
    _, w, h = PRESETS[preset]
    raw = take_dir / f"{preset}-raw.mp4"
    sh(CAP, "export", styled(take_dir / "take.cap", preset, take_dir / f"{preset}.cap"), raw,
       "--fps", 60, "--resolution", f"{w}x{h}", "--quality", "maximum")
    start = max(0.0, info["go"] - info["video_offset"])
    end = info["done"] - info["video_offset"] + 0.2
    final = out_dir / f"{clip_name}-{preset}.mp4"
    sh("ffmpeg", "-loglevel", "error", "-y", "-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", raw,
       "-r", 60, "-c:v", "libx264", "-crf", 16, "-preset", "slow", "-pix_fmt", "yuv420p",
       "-movflags", "+faststart", final)
    raw.unlink()
    return final


def probe(path):
    out = json.loads(sh("ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
                        "-show_entries", "stream=width,height,nb_read_frames:format=duration",
                        "-of", "json", path))
    s = out["streams"][0]
    return {"width": s["width"], "height": s["height"], "frames": int(s["nb_read_frames"]),
            "duration": round(float(out["format"]["duration"]), 2)}


def scan_frames(mp4):
    """Every frame, downscaled. Fails a frame when its outermost pixels stray from
    its own corner colour (something reaches the edge: a crop, or a shadow cut
    off), or when the popover's dark top edge is missing or out of place (a blank
    or half-size frame). Returns the frame count and the failing frame numbers."""
    p = probe(mp4)
    w = 160
    h = round(p["height"] * w / p["width"])
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(mp4), "-vf", f"scale={w}:{h}",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], check=True, capture_output=True).stdout
    size = w * h * 3
    edge_pts = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] \
        + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    tops, bad_edge = [], []
    for n in range(len(raw) // size):
        f = raw[n * size:(n + 1) * size]
        px = lambda x, y: f[(y * w + x) * 3:(y * w + x) * 3 + 3]
        bg = px(0, 0)
        if any(max(abs(c - b) for c, b in zip(px(x, y), bg)) > 6 for x, y in edge_pts):
            bad_edge.append(n)
        # First popover-dark row, scanning down a column a little left of centre:
        # inside even the narrow popover, but clear of the "Added to" toast, which
        # slides over the middle of the popover's top edge.
        col = round(w * 0.40)
        tops.append(next((y for y in range(h) if max(px(col, y)) < 60), None))
    known = sorted(t for t in tops if t is not None)
    median = known[len(known) // 2] if known else None
    bad_body = [n for n, t in enumerate(tops) if t is None or median is None or abs(t - median) > 2]
    return len(tops), bad_edge, bad_body


def check(out_dir):
    """Size, length and frame count for every output, plus numbered stills every
    half second and a contact sheet per output (ffmpeg here has no drawtext; the
    sheet runs left to right, top to bottom, in the stills' order)."""
    problems = []
    for mp4 in sorted(out_dir.glob("*.mp4")):
        preset = mp4.stem.rsplit("-", 1)[1]
        p = probe(mp4)
        _, w, h = PRESETS[preset]
        bad = []
        if (p["width"], p["height"]) != (w, h):
            bad.append(f"size {p['width']}x{p['height']}")
        if not 6 <= p["duration"] <= 16:
            bad.append(f"length {p['duration']} s")
        if abs(p["frames"] - p["duration"] * 60) > p["duration"] * 60 * 0.03:
            bad.append(f"{p['frames']} frames for {p['duration']} s")
        log(f"{mp4.name}: {p['width']}x{p['height']} {p['duration']} s {p['frames']} frames"
            + (" — " + "; ".join(bad) if bad else " — ok"))
        frames, edge, body = scan_frames(mp4)
        if edge:
            bad.append(f"{len(edge)} frames touch the edge (first {edge[:5]})")
        if body:
            bad.append(f"{len(body)} frames lack the popover (first {body[:5]})")
        log(f"  scanned {frames} frames: {len(edge)} at the edge, {len(body)} without the popover")
        problems += [f"{mp4.name}: {b}" for b in bad]
        stills = out_dir / "stills" / mp4.stem
        if stills.exists():
            shutil.rmtree(stills)
        stills.mkdir(parents=True)
        sh("ffmpeg", "-loglevel", "error", "-i", mp4, "-vf", "fps=2", stills / "%02d.png")
        cols = 6
        n = len(list(stills.glob("*.png")))
        rows = (n + cols - 1) // cols
        width = 300 if preset == "social" else 420
        sh("ffmpeg", "-loglevel", "error", "-y", "-framerate", 1, "-i", stills / "%02d.png",
           "-vf", f"scale={width}:-2,tile={cols}x{rows}:padding=4:margin=4:color=white",
           "-frames:v", 1, out_dir / f"contact-{mp4.stem}.png")
    return problems


def next_take(clip_name):
    base = OUT / clip_name
    n = 1
    while (base / f"t{n}").exists():
        n += 1
    return base / f"t{n}"


def take(clip_name):
    take_root = next_take(clip_name)
    infos = {bg: record(clip_name, bg, take_root / ("white" if bg == WHITE else "grey"))
             for bg in (WHITE, GREY)}
    for preset, (bg, _, _) in PRESETS.items():
        sub = take_root / ("white" if bg == WHITE else "grey")
        log(f"exporting {preset}")
        export(sub, infos[bg], preset, clip_name, take_root)
    problems = check(take_root)
    log(f"take: {take_root}" + (f" — PROBLEMS: {problems}" if problems else ""))


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("take", "check"):
        sys.exit(__doc__)
    if sys.argv[1] == "take":
        if sys.argv[2] not in CLIPS:
            sys.exit(f"unknown clip; pick one of {', '.join(CLIPS)}")
        take(sys.argv[2])
    else:
        check(Path(sys.argv[2]))
