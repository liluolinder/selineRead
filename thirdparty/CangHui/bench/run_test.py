#!/usr/bin/env python3
"""Self-test for the benchmark regression gate (bench/run.py --check).

The gate has three jobs that are each easy to get wrong: ignore a machine that is uniformly slower than
the one that recorded the baseline, still catch a single case that really did regress (even while that
machine is slow), and admit when a run is too noisy to judge at all. Synthetic fleets exercise all
three, so the gate itself is verified without needing a quiet machine to run the real benchmarks on.

Run: python bench/run_test.py
"""

import importlib.util
import io
import random
import sys
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.dont_write_bytecode = True  # importing run.py for its logic should not litter a __pycache__
spec = importlib.util.spec_from_file_location("benchrun", Path(__file__).with_name("run.py"))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)

# A synthetic fleet: 12 frame cases from 1ms to 12ms, all well past the material floor.
BASE = {f"frame|g|case{i}": float(i * 1_000_000) for i in range(1, 13)}


def frames(scale):
    """Build a result set where each case i is scale(i) times its baseline."""
    return [
        {"kind": "frame", "group": "g", "name": f"case{i}", "ns": BASE[f"frame|g|case{i}"] * scale(i)}
        for i in range(1, 13)
    ]


def check(recs, base=None):
    run.load_baseline = lambda: dict(base or BASE)
    buf = io.StringIO()
    with redirect_stdout(buf), redirect_stderr(buf):
        code = run.check_regressions(recs, [])
    return code, buf.getvalue()


failures = []


def expect(name, cond, detail=""):
    if cond:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}\n{detail}")
        failures.append(name)


print("bench regression-gate self-test\n")

# A box reproducing the baseline: nothing moved, nothing to report.
code, out = check(frames(lambda i: 1.0))
expect("baseline reproduced -> pass", code == 0 and "No regressions" in out, out)

# A uniformly 3x slower box. The whole fleet moved together, so that is the machine, not the code —
# this is the case that made the old absolute check flag all 39 real cases at once.
code, out = check(frames(lambda i: 3.0))
expect("uniform 3x machine -> pass", code == 0 and "No regressions" in out, out)
expect("uniform 3x is reported as the machine factor", "3.00x" in out, out)

# One case twice as slow as its peers on an otherwise steady box: the gate must fail and name it.
code, out = check(frames(lambda i: 2.0 if i == 5 else 1.0))
expect("one real regression -> fail", code == 1, out)
expect("regression is named", "case5" in out, out)

# The same regression hiding underneath a 3x-slow machine: normalising must still surface it.
code, out = check(frames(lambda i: 6.0 if i == 5 else 3.0))
expect("regression under a slow machine -> fail", code == 1, out)
expect("regression is named despite the machine", "case5" in out, out)

# A case that got faster than its peers is an improvement, not a regression.
code, out = check(frames(lambda i: 0.4 if i == 7 else 1.0))
expect("an improvement -> pass", code == 0, out)

# A commit that speeds up MOST cases must not turn the untouched rest into "regressions vs peers":
# the fleet median drops below 1, and flagging normalises by max(median, 1) to absorb that.
code, out = check(frames(lambda i: 0.4 if i <= 7 else 1.0))
expect("majority improvement -> unchanged cases not flagged", code == 0 and "Regressions" not in out, out)

# Too few material cases and the median is meaningless (a lone regressed case can be its own median):
# the gate must decline to judge, not pass or fail.
small_base = {f"frame|g|case{i}": float(i * 1_000_000) for i in range(1, 4)}
small = [{"kind": "frame", "group": "g", "name": f"case{i}",
          "ns": small_base[f"frame|g|case{i}"] * (2.0 if i == 2 else 1.0)} for i in range(1, 4)]
code, out = check(small, small_base)
expect("tiny fleet -> inconclusive, not a verdict", code == 0 and "INCONCLUSIVE" in out, out)

# When nothing material is comparable the gate has no coverage at all — it must say so instead of
# quietly gating the jitter-dominated sub-material cases (or printing a false 'No regressions').
micro_base = {f"frame|g|micro{i}": 100_000.0 for i in range(1, 6)}
micro = [{"kind": "frame", "group": "g", "name": f"micro{i}", "ns": 100_000.0} for i in range(1, 6)]
code, out = check(micro, micro_base)
expect("all sub-material -> inconclusive no-coverage",
       code == 0 and "INCONCLUSIVE" in out and "No regressions" not in out, out)

# A sub-material case that exploded is never a verdict, but it must be VISIBLE as an FYI line —
# a 20x jump on a 10us case can be an algorithmic slip that will scale with content.
tiny_burst_base = dict(BASE)
tiny_burst_base["frame|g|tinyburst"] = 10_000.0
tiny_burst = [{"kind": "frame", "group": "g", "name": "tinyburst", "ns": 200_000.0}]
code, out = check(frames(lambda i: 1.0) + tiny_burst, tiny_burst_base)
expect("cheap case exploding -> pass but listed as FYI",
       code == 0 and "FYI" in out and "tinyburst" in out, out)

# A genuinely noisy run (cases disagreeing wildly after normalising, as a P/E-core box does) cannot
# separate signal from scheduling noise. It must say so rather than fail on a coin flip.
random.seed(7)
code, out = check(frames(lambda i: random.uniform(0.6, 1.8)))
expect("noisy run -> inconclusive, does not fail", code == 0 and "INCONCLUSIVE" in out, out)

# A case too cheap to cost a frame doubling is not a regression: 10us -> 20us cannot hurt anything,
# and sub-millisecond cases are where nearly all the jitter lives.
tiny_base = dict(BASE)
tiny_base["frame|g|tiny"] = 10_000.0
tiny = [{"kind": "frame", "group": "g", "name": "tiny", "ns": 20_000.0}]
code, out = check(frames(lambda i: 1.0) + tiny, tiny_base)
expect("sub-material case ignored", code == 0 and "1 cheaper" in out, out)

# With no baseline there is nothing to compare against, which is a setup error, not a pass.
run.load_baseline = lambda: {}
buf = io.StringIO()
with redirect_stdout(buf), redirect_stderr(buf):
    code = run.check_regressions(frames(lambda i: 1.0), [])
expect("missing baseline -> setup error (2)", code == 2, buf.getvalue())

print()
if failures:
    print(f"{len(failures)} FAILED: {failures}")
    sys.exit(1)
print("all gate self-tests passed")
