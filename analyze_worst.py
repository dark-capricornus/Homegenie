"""Drill into the worst INP interaction."""
import json
from collections import defaultdict, Counter

PATH = r"D:\Homegenie\Trace-20260505T015627.json"

print("Loading...", flush=True)
with open(PATH, "r", encoding="utf-8") as f:
    data = json.load(f)
events = data.get("traceEvents", data) if isinstance(data, dict) else data

# Find worst interaction's wall time
worst_iid = 7541
target_ts_us = None
target_dur_ms = 877.576

# EventTiming records use trace ts (microseconds). Find earliest event for this interaction.
for e in events:
    if not isinstance(e, dict): continue
    if e.get("name") != "EventTiming": continue
    a = (e.get("args") or {}).get("data") or {}
    if a.get("interactionId") == worst_iid:
        if target_ts_us is None or e.get("ts", 0) < target_ts_us:
            target_ts_us = e.get("ts")

print(f"Worst interaction id={worst_iid} starts ts={target_ts_us} us")
window_start = target_ts_us
window_end = target_ts_us + int(target_dur_ms * 1000) + 50_000  # +50ms cushion

# Collect main-thread events in this window
in_window = []
for e in events:
    if not isinstance(e, dict): continue
    ts = e.get("ts")
    if ts is None: continue
    if ts < window_start or ts > window_end: continue
    in_window.append(e)

print(f"Events in window: {len(in_window)}")

# Top consumers by duration in window
by_name_dur = defaultdict(float)
by_name_count = Counter()
for e in in_window:
    n = e.get("name", "?")
    d = e.get("dur", 0)
    if d:
        by_name_dur[n] += d
        by_name_count[n] += 1

print("\n=== Top time consumers in worst-interaction window (ms total) ===")
for n, d in sorted(by_name_dur.items(), key=lambda x: -x[1])[:25]:
    print(f"  {d/1000:>9.2f}ms  x{by_name_count[n]:<6}  {n}")

# Find the largest individual tasks in window
print("\n=== Top 15 individual events in window ===")
big = sorted([e for e in in_window if e.get("dur", 0) > 5000], key=lambda x: -x.get("dur", 0))[:15]
for e in big:
    args = e.get("args", {}) or {}
    data_arg = args.get("data") if isinstance(args, dict) else None
    extra = ""
    if isinstance(data_arg, dict):
        for k in ("functionName", "url", "type", "frame", "scriptId"):
            if k in data_arg:
                extra += f" {k}={data_arg[k]}"
    print(f"  {e.get('dur',0)/1000:>8.2f}ms  {e.get('name')}  cat={e.get('cat','')[:40]}{extra}")

# Look specifically for V8 / script execution / Flutter-related markers
print("\n=== Script/V8 events in window ===")
script_names = ("FunctionCall", "EvaluateScript", "v8.run", "v8.callFunction",
                "RunMicrotasks", "MajorGC", "MinorGC", "ParseScript", "CompileScript",
                "V8.Execute", "RunTask")
for name in script_names:
    matches = [e for e in in_window if e.get("name") == name and e.get("dur", 0) > 10000]
    if matches:
        total = sum(e.get("dur", 0) for e in matches) / 1000
        print(f"  {name}: {len(matches)} events, total {total:.1f}ms, max {max(e.get('dur',0) for e in matches)/1000:.1f}ms")

# Profile chunk samples — where is V8 spending time?
print("\n=== Looking for sampled stack frames in window ===")
profile_chunks = [e for e in in_window if e.get("name") == "ProfileChunk"]
print(f"ProfileChunk events: {len(profile_chunks)}")

# Aggregate function names from cpuProfile nodes
fn_samples = Counter()
for pc in profile_chunks:
    args = pc.get("args", {})
    cpuProfile = (args.get("data") or {}).get("cpuProfile") if isinstance(args.get("data"), dict) else None
    if not cpuProfile: continue
    nodes = cpuProfile.get("nodes", [])
    samples = cpuProfile.get("samples", [])
    id_to_fn = {}
    for n in nodes:
        cf = n.get("callFrame", {})
        fn = cf.get("functionName") or "(anonymous)"
        url = cf.get("url", "")
        id_to_fn[n["id"]] = f"{fn} @ {url[-60:] if url else ''}"
    for sid in samples:
        if sid in id_to_fn:
            fn_samples[id_to_fn[sid]] += 1

print("\n=== Top sampled functions in worst-interaction window ===")
for fn, n in fn_samples.most_common(20):
    print(f"  {n:>5}  {fn}")
