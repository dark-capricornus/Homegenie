"""Analyze Chrome DevTools trace for INP contributors."""
import json
import sys
from collections import defaultdict

PATH = r"D:\Homegenie\Trace-20260505T015627.json"

print("Loading trace (this may take a moment)...", flush=True)
with open(PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

events = data.get("traceEvents", data) if isinstance(data, dict) else data
print(f"Total events: {len(events):,}", flush=True)

# Group by interactionId for EventTiming entries
interactions = defaultdict(list)
long_tasks = []
event_timings = []
categories = defaultdict(int)
event_names = defaultdict(int)

for e in events:
    if not isinstance(e, dict):
        continue
    cat = e.get("cat", "")
    name = e.get("name", "")
    categories[cat] += 1
    event_names[name] += 1

    args = e.get("args", {}) or {}
    data_arg = args.get("data", {}) if isinstance(args, dict) else {}

    # EventTiming - the official INP source
    if name == "EventTiming" and isinstance(data_arg, dict):
        iid = data_arg.get("interactionId") or 0
        if iid and iid != 0:
            interactions[iid].append({
                "type": data_arg.get("type"),
                "duration": data_arg.get("duration"),
                "processingStart": data_arg.get("processingStart"),
                "processingEnd": data_arg.get("processingEnd"),
                "startTime": data_arg.get("startTime"),
                "nodeName": data_arg.get("nodeName") or data_arg.get("nodeId"),
                "frame": data_arg.get("frame"),
            })
        event_timings.append(data_arg)

    # Long tasks
    if name in ("RunTask", "LongTask") and "dur" in e:
        if e["dur"] > 50_000:  # > 50ms
            long_tasks.append({
                "name": name,
                "dur_ms": e["dur"] / 1000,
                "ts": e.get("ts"),
            })

print("\n=== Top categories ===")
for c, n in sorted(categories.items(), key=lambda x: -x[1])[:10]:
    print(f"  {n:>10,}  {c}")

print("\n=== Top event names ===")
for c, n in sorted(event_names.items(), key=lambda x: -x[1])[:20]:
    print(f"  {n:>10,}  {c}")

print(f"\n=== EventTiming entries: {len(event_timings)} ===")
print(f"=== Unique interactions: {len(interactions)} ===")

# Compute per-interaction INP
interaction_inp = []
for iid, parts in interactions.items():
    max_dur = max((p.get("duration") or 0) for p in parts)
    typ = parts[0].get("type")
    node = parts[0].get("nodeName")
    interaction_inp.append((iid, max_dur, typ, node, parts))

interaction_inp.sort(key=lambda x: -x[1])

print("\n=== TOP 10 interactions by duration (= INP candidates) ===")
for iid, dur, typ, node, parts in interaction_inp[:10]:
    print(f"  id={iid}  dur={dur}ms  type={typ}  node={node}  parts={len(parts)}")
    for p in parts:
        ps = p.get("processingStart")
        pe = p.get("processingEnd")
        st = p.get("startTime")
        proc = (pe - ps) if (ps is not None and pe is not None) else None
        input_delay = (ps - st) if (ps is not None and st is not None) else None
        print(f"      type={p.get('type')} dur={p.get('duration')}ms inputDelay={input_delay}ms processing={proc}ms")

# If no interactions found via EventTiming, check for raw input events
if not interactions:
    print("\nNo EventTiming entries with interactionId found.")
    print("Looking for raw input/click events...")
    input_events = [e for e in events if isinstance(e, dict) and e.get("name") in (
        "Event", "EventDispatch", "Click", "PointerDown", "PointerUp", "Tap"
    )]
    print(f"Raw input-like events: {len(input_events)}")
    sample = sorted([e for e in input_events if "dur" in e], key=lambda e: -e.get("dur", 0))[:10]
    for e in sample:
        a = (e.get("args") or {}).get("data") or {}
        print(f"  {e.get('name')} dur={e.get('dur',0)/1000:.1f}ms type={a.get('type')} target={a.get('nodeName')}")

print(f"\n=== Long tasks (>50ms): {len(long_tasks)} ===")
for t in sorted(long_tasks, key=lambda x: -x["dur_ms"])[:10]:
    print(f"  {t['dur_ms']:.1f}ms  {t['name']}  ts={t['ts']}")
