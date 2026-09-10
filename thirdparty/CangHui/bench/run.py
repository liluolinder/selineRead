#!/usr/bin/env python3
"""One-click CangHui benchmark runner (cross-platform).

Builds and runs the headless benchmarks, parses their machine-readable @@RESULT lines, and renders
a self-contained HTML report (bench/results/report.html) that lays each per-frame cost against the
interactive frame budgets (120 / 60 / 30 fps) and auto-derives a strengths / weaknesses summary.

Headless numbers measure CPU-side build / layout / draw only (text is estimated, not rasterised).
With --display it also runs the self-terminating display benchmarks (bench/planner_scroll,
bench/large_table), which measure real per-frame cost including SDL text rasterisation, and folds
those in. See bench/README.md.

Usage:
    python bench/run.py                 # build + run headless, write the report
    python bench/run.py --open          # ...and open it in a browser
    python bench/run.py --no-run        # reuse the last capture, just re-render the report
    python bench/run.py --display       # also run the display benchmarks (opens brief windows)
    python bench/run.py --save-baseline # record current per-frame costs as the regression baseline
    python bench/run.py --check         # fail (exit 1) if a case regressed relative to its peers
    python bench/run_test.py            # self-test the --check gate logic

--check judges each case against how the *other* cases moved rather than against raw baseline times,
so a machine that is uniformly slower than the one that recorded the baseline does not read as 39
regressions; and it reports its own noise, answering "inconclusive" when a run cannot tell a
regression from scheduling jitter. Only --check is normalised — the report and the budget counts are
raw measurements of this box.
"""

import argparse
import statistics
import subprocess
import sys
import webbrowser
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"
TEMPLATE = ROOT / "report.template.html"
RAW = RESULTS / "micro.out.txt"
REPORT = RESULTS / "report.html"
BASELINE = ROOT / "baseline.json"

FRAME_60 = 16_666_667   # ns budget for 60 fps
FRAME_120 = 8_333_333   # ns budget for 120 fps
FRAME_30 = 33_333_333   # ns budget for 30 fps

# --check flags a case that slowed this much MORE than its peers did. It is a *relative* threshold:
# see check_regressions for why comparing raw times to the baseline does not survive a slow machine.
REGRESSION = 1.25
# Cases cheaper than this cannot move a frame, and carry nearly all the measurement jitter (a 10 us
# case can double on scheduler noise alone), so they are never gated; ones that still moved a lot are
# listed after the verdict as FYI only.
MATERIAL_NS = 500_000
# Fewer material cases than this and the fleet median is meaningless (a lone regressed case can be its
# own median and vanish), so the gate declines to judge instead.
MIN_FLEET = 8
# A fleet median past this reads as "this box is slower than the one that recorded the baseline",
# which is worth saying out loud because it makes absolute times incomparable.
MACHINE_NOTE = 1.15
# How many robust deviations past the fleet a case must sit before it is called a regression. This only
# bites on a noisy run: on a quiet one the REGRESSION floor is the wider of the two and stays in charge.
NOISE_K = 4
# Residual spread (median absolute deviation about the fleet) past which a run simply cannot gate. A
# machine that schedules some cases on performance cores and others on efficiency cores does not slow
# down uniformly, and no threshold separates signal from that. Say so instead of guessing.
NOISE_LIMIT = 0.10

RATING_LABEL = {
    "ok": "120fps 就绪",
    "good": "60fps 就绪",
    "warn": "30fps 及格",
    "bad": "低于 30fps",
}

DISPLAY_APPS = ["planner_scroll", "large_table"]


def run_cjpm(pkg_dir: Path, action: str = "run") -> list:
    """Run `cjpm <action>` in pkg_dir and return its stdout as a list of lines."""
    proc = subprocess.run(
        ["cjpm", action],
        cwd=str(pkg_dir),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0 and not proc.stdout:
        sys.stderr.write(proc.stderr or "")
    return proc.stdout.splitlines()


def parse_results(lines):
    frame, micro, display = [], [], []
    for ln in lines:
        if not ln.startswith("@@RESULT"):
            continue
        parts = ln.strip().split("|")
        if len(parts) < 6:
            continue
        rec = {
            "kind": parts[1],
            "group": parts[2],
            "name": parts[3],
            "ns": int(parts[4]),
            "iters": int(parts[5]),
        }
        if rec["kind"] == "frame":
            frame.append(rec)
        elif rec["kind"] == "display":
            display.append(rec)
        else:
            micro.append(rec)
    return frame, micro, display


def parse_counts(lines):
    counts = []
    for ln in lines:
        if not ln.startswith("@@COUNT"):
            continue
        parts = ln.strip().split("|")
        if len(parts) < 4:
            continue
        counts.append({"group": parts[1], "name": parts[2], "count": int(parts[3])})
    return counts


def fmt_dur(ns: float) -> str:
    ns = float(ns)
    if ns < 10_000:
        return f"{ns:.0f} ns"
    if ns < 10_000_000:
        return f"{ns / 1000:.2f} us"
    return f"{ns / 1_000_000:.3f} ms"


def frame_class(ns: float) -> str:
    if ns <= FRAME_120:
        return "ok"
    if ns <= FRAME_60:
        return "good"
    if ns <= FRAME_30:
        return "warn"
    return "bad"


def esc(text: str) -> str:
    return (str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def fps_of(ns: float) -> int:
    return round(1e9 / ns) if ns > 0 else 0


def frame_row(rec) -> str:
    cls = frame_class(rec["ns"])
    fps = fps_of(rec["ns"])
    pct = min(100, round(rec["ns"] / FRAME_60 * 100))
    return f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""


def micro_row(rec, max_ns) -> str:
    ops = fps_of(rec["ns"])
    pct = max(5, round(rec["ns"] / max_ns * 100)) if max_ns > 0 else 5
    return f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{ops:,}</td>
        <td class="barcell"><div class="bar"><div class="fill micro" style="width:{pct}%"></div></div></td>
      </tr>
"""


def build_display_section(display) -> str:
    if not display:
        return (
            '<div class="note"><p class="muted" style="margin:0">尚未采集上机实测数据。运行 '
            "<code>python bench/run.py --display</code> 会启动自终止的端到端基准（短暂开窗、跑满固定帧数后自动退出），"
            "将含 GPU 与文本光栅的真实帧率并入本报告。</p></div>"
        )
    rows = ""
    for rec in sorted(display, key=lambda r: r["ns"], reverse=True):
        cls = frame_class(rec["ns"])
        fps = fps_of(rec["ns"])
        pct = min(100, round(rec["ns"] / FRAME_60 * 100))
        rows += f"""      <tr>
        <td class="grp">{esc(rec['group'])}</td>
        <td>{esc(rec['name'])}</td>
        <td class="num">{fmt_dur(rec['ns'])}</td>
        <td class="num">{fps}</td>
        <td><span class="badge {cls}">{RATING_LABEL[cls]}</span></td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>用例</th><th>每帧耗时（真实）</th><th>实测帧率</th><th>评级</th><th>预算占用（相对 16.67ms）</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>"""


def build_count_section(counts) -> str:
    if not counts:
        return ('<div class="note"><p class="muted" style="margin:0">无文本度量诊断数据。</p></div>')
    mx = max((c["count"] for c in counts), default=1) or 1
    rows = ""
    for c in sorted(counts, key=lambda r: r["count"], reverse=True):
        pct = max(3, round(c["count"] / mx * 100))
        cls = "bad" if c["count"] > 500 else ("warn" if c["count"] > 120 else "ok")
        rows += f"""      <tr>
        <td>{esc(c['name'])}</td>
        <td class="num">{c['count']:,}</td>
        <td class="barcell"><div class="bar"><div class="fill {cls}" style="width:{pct}%"></div></div></td>
      </tr>
"""
    return f"""<div class="tablewrap">
    <table>
      <thead><tr><th>场景</th><th>每帧文本度量次数</th><th>相对量（越短越好）</th></tr></thead>
      <tbody>
{rows}      </tbody>
    </table>
  </div>
  <p class="muted" style="font-size:12.5px">每帧文本度量次数 × 单次 SDL_ttf 成本 ≈ 该帧文本预算。未窗口化的组合内容页每帧上千次度量，是 planner 右栏滚动帧率偏低的主因；窗口化的表格与列表只度量可见行，故低一到两个数量级。</p>"""


def git_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True,
        )
        return out.stdout.strip() or "(no git)"
    except Exception:
        return "(no git)"


def toolchain() -> str:
    try:
        out = subprocess.run(["cjc", "--version"], capture_output=True, text=True)
        line = (out.stdout or out.stderr).splitlines()
        return line[0].strip() if line else "-"
    except Exception:
        return "-"


def load_baseline():
    import json
    if BASELINE.exists():
        return json.loads(BASELINE.read_text(encoding="utf-8"))
    return {}


def save_baseline(frame, display):
    import json
    data = {f"{r['kind']}|{r['group']}|{r['name']}": r["ns"] for r in list(frame) + list(display)}
    BASELINE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Baseline saved to {BASELINE} ({len(data)} cases).")


def machine_factor(recs, base):
    """The median case's slowdown vs baseline, over cases big enough to measure reliably.

    When every case moves by the same factor, that factor is the machine — this box has been measured
    running 2.5-3x slow for hours at a stretch (thermal/power limits, or work parked on E-cores) — not
    the code. Returns (factor, gated, pairs): the factor, the material cases worth gating, and every
    comparable case. factor is None when no case is material — sub-material cases are never gated in
    its place, since they are exactly where scheduler jitter lives.
    """
    pairs = []
    for r in recs:
        was = base.get(f"{r['kind']}|{r['group']}|{r['name']}")
        if was and was > 0:
            pairs.append({
                "key": f"{r['kind']}|{r['group']}|{r['name']}",
                "was": was,
                "now": r["ns"],
                "ratio": r["ns"] / was,
            })
    gated = [p for p in pairs if max(p["was"], p["now"]) >= MATERIAL_NS]
    if not gated:
        return None, [], pairs
    return statistics.median([p["ratio"] for p in gated]), gated, pairs


def check_regressions(frame, display) -> int:
    """Fail on a case that got slower than its peers did — and say so when the run cannot tell.

    Comparing raw times against the baseline is what this used to do, and it does not survive a slow
    machine: at a uniform 3x every one of the 39 cases "regresses" and the gate is pure noise. Two
    things fix that. Each case is judged against the *median* case, so a machine-wide slowdown cancels
    out; and the run measures its own residual spread, because a box that parks some cases on
    efficiency cores and others on performance cores does not slow down uniformly and no threshold
    separates a real regression from that. When the spread is too wide the honest answer is
    "inconclusive", not a coin flip — suspects are still listed, but the gate does not fail on noise.

    Two blind spots are inherent to judging against the median, so they are stated rather than hidden:
    a regression that slows the *majority* of cases (not only all of them) is absorbed into the machine
    factor and reads as a slow box — the factor is always printed, and a big number there means "re-run
    somewhere idle before trusting a clean result". And the flagging side normalises by max(factor, 1),
    so a commit that speeds up most cases does not turn the untouched rest into false regressions.
    """
    base = load_baseline()
    if not base:
        print("No baseline.json; run with --save-baseline first.", file=sys.stderr)
        return 2
    factor, gated, pairs = machine_factor(list(frame) + list(display), base)
    if not pairs:
        print("No cases in common with baseline.json; nothing to check.", file=sys.stderr)
        return 2
    if factor is None:
        print(f"INCONCLUSIVE: all {len(pairs)} comparable cases are under {fmt_dur(MATERIAL_NS)} — "
              f"nothing big enough to gate (sub-material cases are pure scheduler jitter).")
        return 0
    if len(gated) < MIN_FLEET:
        print(f"INCONCLUSIVE: only {len(gated)} material case(s) in common with the baseline — too few "
              f"for a meaningful fleet median (need {MIN_FLEET}). Raw ratios:")
        for p in sorted(gated, key=lambda p: -p["ratio"]):
            print(f"  {p['key']}: {fmt_dur(p['was'])} -> {fmt_dur(p['now'])}   {p['ratio']:.2f}x raw")
        return 0
    skipped = len(pairs) - len(gated)

    # Robust spread of the normalised ratios about the fleet: how much cases disagree once the shared
    # machine factor is divided out. On an idle box this is a couple of percent. Flagging divides by
    # max(factor, 1): a fleet that mostly got FASTER (factor < 1) must not turn its unchanged cases
    # into "regressions vs peers", while a slow machine (factor > 1) still normalises fully.
    spread = statistics.median([abs(p["ratio"] / factor - 1.0) for p in gated])
    bound = 1.0 + max(REGRESSION - 1.0, NOISE_K * spread)
    flag_factor = max(factor, 1.0)
    suspects = sorted((p for p in gated if p["ratio"] / flag_factor > bound),
                      key=lambda p: -p["ratio"] / flag_factor)

    print(f"Checked {len(gated)} cases of at least {fmt_dur(MATERIAL_NS)}"
          + (f" ({skipped} cheaper ones ignored: too small to cost a frame)" if skipped else ""))
    print(f"Machine factor: {factor:.2f}x (median case vs its baseline)  |  "
          f"noise: +/-{spread * 100:.0f}%  |  flags past {bound:.2f}x vs peers")
    if factor >= MACHINE_NOTE:
        print(f"  This box is running ~{factor:.1f}x slower than the one that recorded the baseline, so")
        print(f"  absolute times and the 60fps-budget counts are NOT comparable to it; per-case checks")
        print(f"  are normalised against it. A regression that slowed everything equally would look the")
        print(f"  same — re-run on an idle machine to rule that out.")

    if spread > NOISE_LIMIT:
        print(f"\nINCONCLUSIVE: cases disagree by +/-{spread * 100:.0f}% after normalising, so this run"
              f" cannot tell a\nregression from scheduling noise (a regression under ~{(bound - 1) * 100:.0f}%"
              f" would be invisible here).\nRe-run on an idle machine for a verdict.")
        if suspects:
            print(f"\nSuspects past {bound:.2f}x vs peers — most likely still noise, worth a second look:")
            for p in suspects:
                print(f"  {p['key']}: {fmt_dur(p['was'])} -> {fmt_dur(p['now'])}"
                      f"   {p['ratio']:.2f}x raw, {p['ratio'] / flag_factor:.2f}x vs peers")
        return 0

    if suspects:
        print(f"\nRegressions (>{(bound - 1) * 100:.0f}% slower than the fleet moved):", file=sys.stderr)
        for p in suspects:
            print(f"  {p['key']}: {fmt_dur(p['was'])} -> {fmt_dur(p['now'])}"
                  f"   {p['ratio']:.2f}x raw, {p['ratio'] / flag_factor:.2f}x vs peers", file=sys.stderr)
        note_cheap_movers(pairs, gated, flag_factor, bound)
        return 1
    print("No regressions past threshold (normalised against the fleet).")
    note_cheap_movers(pairs, gated, flag_factor, bound)
    return 0


def note_cheap_movers(pairs, gated, flag_factor, bound):
    """List sub-material cases that moved past the bound — visibility only, never a verdict.

    A 20us case jumping 20x cannot cost a frame today, but it can be an algorithmic slip that will
    scale with content, so it deserves a line in the output even though it is far too jittery to gate.
    """
    gated_keys = {p["key"] for p in gated}
    movers = sorted((p for p in pairs if p["key"] not in gated_keys
                     and p["ratio"] / flag_factor > bound), key=lambda p: -p["ratio"] / flag_factor)
    if movers:
        print(f"\nSub-material cases that also moved (too small to gate; FYI only):")
        for p in movers:
            print(f"  {p['key']}: {fmt_dur(p['was'])} -> {fmt_dur(p['now'])}   {p['ratio']:.2f}x raw")


def main() -> int:
    ap = argparse.ArgumentParser(description="CangHui benchmark runner + HTML report.")
    ap.add_argument("--no-run", action="store_true", help="reuse the last capture instead of rebuilding")
    ap.add_argument("--open", action="store_true", help="open the report when finished")
    ap.add_argument("--display", action="store_true", help="also run the display benchmarks")
    ap.add_argument("--save-baseline", action="store_true", help="record current costs as the regression baseline")
    ap.add_argument("--check", action="store_true", help="exit non-zero if a case regressed past the threshold")
    args = ap.parse_args()

    RESULTS.mkdir(parents=True, exist_ok=True)

    if args.no_run:
        if not RAW.exists():
            print(f"No cached output at {RAW}; run without --no-run first.", file=sys.stderr)
            return 2
        lines = RAW.read_text(encoding="utf-8").splitlines()
    else:
        print("Building and running headless benchmarks (bench/micro)...")
        lines = run_cjpm(ROOT / "micro", "run")
        RAW.write_text("\n".join(lines), encoding="utf-8")

    frame, micro, display = parse_results(lines)
    counts = parse_counts(lines)

    if args.display and not args.no_run:
        for app in DISPLAY_APPS:
            app_dir = ROOT / app
            if not (app_dir / "cjpm.toml").exists():
                continue
            print(f"Running display benchmark bench/{app} (opens a brief window)...")
            _f, _m, d = parse_results(run_cjpm(app_dir, "run"))
            display.extend(d)

    if not frame and not micro and not display:
        print("No @@RESULT lines parsed. Did the build or run fail?", file=sys.stderr)
        return 2

    if args.save_baseline:
        save_baseline(frame, display)
    if args.check:
        return check_regressions(frame, display)

    # --- render ---
    frame_sorted = sorted(frame, key=lambda r: r["ns"], reverse=True)
    over = [r for r in frame_sorted if r["ns"] > FRAME_60]
    comfy = [r for r in frame_sorted if r["ns"] <= FRAME_120]

    worst = "n/a"
    if frame_sorted:
        w = frame_sorted[0]
        worst = f"{esc(w['group'])} / {esc(w['name'])} - {fmt_dur(w['ns'])} (~{fps_of(w['ns'])} fps)"

    frame_rows = "".join(frame_row(r) for r in frame_sorted)

    micro_rows = ""
    groups = {}
    for r in micro:
        groups.setdefault(r["group"], []).append(r)
    for name, recs in groups.items():
        mx = max(r["ns"] for r in recs)
        for r in sorted(recs, key=lambda r: r["ns"], reverse=True):
            micro_rows += micro_row(r, mx)

    weak = ""
    for r in over:
        weak += f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - {fmt_dur(r['ns'])} (~{fps_of(r['ns'])} fps)</li>\n"
    if not weak:
        weak = '        <li class="muted">没有超出 60fps 预算的用例。</li>\n'

    strong = ""
    for r in sorted(comfy, key=lambda r: r["ns"]):
        strong += f"        <li><b>{esc(r['group'])} / {esc(r['name'])}</b> - {fmt_dur(r['ns'])}</li>\n"
    if not strong:
        strong = '        <li class="muted">暂无进入 120fps 区间的帧用例。</li>\n'

    meta = f"生成于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ｜ 提交 {git_commit()} ｜ {esc(toolchain())}"

    html = TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "{{META}}": meta,
        "{{FRAME_COUNT}}": str(len(frame)),
        "{{OVER_COUNT}}": str(len(over)),
        "{{COMFORT_COUNT}}": str(len(comfy)),
        "{{WORST}}": worst,
        "{{FRAME_ROWS}}": frame_rows,
        "{{DISPLAY_SECTION}}": build_display_section(display),
        "{{COUNT_SECTION}}": build_count_section(counts),
        "{{WEAK_ITEMS}}": weak,
        "{{STRONG_ITEMS}}": strong,
        "{{MICRO_ROWS}}": micro_rows,
    }
    for token, value in replacements.items():
        html = html.replace(token, value)

    REPORT.write_text(html, encoding="utf-8")
    print(f"\nReport written to {REPORT}")
    print(f"Frame cases: {len(frame)}  |  over 60fps budget: {len(over)}  |  at 120fps: {len(comfy)}"
          + (f"  |  display cases: {len(display)}" if display else ""))
    # The budget counts above are raw measurements, so say so when this box is not running at the speed
    # the baseline was taken on: on a 3x-slow machine the heaviest cases cross 16.67ms on their own and
    # the counts read like a regression that is not there. --check is normalised; these counts are not.
    factor, gated, _ = machine_factor(frame, load_baseline())
    if factor is not None and factor >= MACHINE_NOTE:
        would = sum(1 for r in frame if r["ns"] / factor > FRAME_60)
        print(f"  note: this box is running ~{factor:.1f}x slower than the baseline machine"
              f" ({len(gated)} cases compared); at baseline speed ~{would} would be over the 60fps budget."
              f" Use --check (normalised) to judge regressions.")

    if args.open:
        webbrowser.open(REPORT.as_uri())
    return 0


if __name__ == "__main__":
    sys.exit(main())
