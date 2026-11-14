#!/usr/bin/env python3
"""分析 `%TEMP%\\seline_read_debug.log` 里最近一次手动测试（DIAG SESSION）。

用法：
    python scripts/analyze_diag.py              # 分析最近一次会话
    python scripts/analyze_diag.py --all        # 分析文件里所有会话
    python scripts/analyze_diag.py --tail 400   # 只看最后 400 行

输出：
    1) 会话概览：时长、慢帧数、慢帧分布（按页面 / 是否 loading）
    2) 慢帧明细：帧号、耗时、页面、侧栏状态、加载状态
    3) 侧栏动画质量：每次开关的帧数、耗时、宽度序列是否单调/均匀
"""
import argparse
import os
import re
import statistics
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass

LOG_PATH = os.path.join(os.environ.get("TEMP", "."), "seline_read_debug.log")

# 兼容两种格式：旧版以 slow= 结尾；新版追加了 gcc/gct/freed
RE_FRAME = re.compile(
    r"^FRAME tick=(\d+) ms=(\d+) page=(\S+) rail=(\S+) scroll=(\d+) "
    r"cells=(\S+) loading=(\S+) slow=(\S+)(?: gcc=(\d+) gct=(\d+) freed=(\d+))?$"
)
RE_RAIL = re.compile(r"^RAIL dt=([\d.-]+) t=([\d.-]+) w=([\d.-]+) target=([\d.-]+)$")
RE_MARK = re.compile(r"^MARK (.+)$")


def read_sessions(path):
    """把日志切成若干会话（以 DIAG SESSION START 为界）。"""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        print(f"读不到日志：{path}（{error}）")
        sys.exit(1)

    sessions = []
    current = None
    for line in lines:
        if line.strip() == "=== DIAG SESSION START ===":
            current = []
            sessions.append(current)
            continue
        if current is None:
            continue
        current.append(line)
    return sessions


def parse_session(lines):
    frames = []
    rails = []
    marks = []
    for line in lines:
        text = line.strip()
        match = RE_FRAME.match(text)
        if match:
            frames.append(
                {
                    "tick": int(match.group(1)),
                    "ms": int(match.group(2)),
                    "page": match.group(3),
                    "rail": match.group(4),
                    "scroll": int(match.group(5)),
                    "cells": match.group(6),
                    "loading": match.group(7),
                    "slow": match.group(8) == "true",
                    "gcc": int(match.group(9)) if match.group(9) else None,
                    "freed": int(match.group(11)) if match.group(11) else None,
                }
            )
            continue
        match = RE_RAIL.match(text)
        if match:
            rails.append(
                {
                    "dt": float(match.group(1)),
                    "t": float(match.group(2)),
                    "w": float(match.group(3)),
                    "target": float(match.group(4)),
                }
            )
            continue
        match = RE_MARK.match(text)
        if match:
            marks.append(match.group(1))
    return frames, rails, marks


def summarize(frames, rails, marks):
    slow = [f for f in frames if f["slow"]]
    heartbeats = [f for f in frames if not f["slow"]]
    tick_max = max((f["tick"] for f in frames), default=0)
    tick_min = min((f["tick"] for f in frames), default=0)

    print(f"记录到的帧样本：{len(frames)} 条（帧号 {tick_min}..{tick_max}）")
    print(f"  心跳（正常帧）：{len(heartbeats)} 条    慢帧（>18ms）：{len(slow)} 条")
    if marks:
        print("  事件标记：" + " | ".join(marks[:20]) + (" …" if len(marks) > 20 else ""))
    if not slow:
        print("  [OK] 没有慢帧：手动测试期间没有 >18ms 的帧")
        return

    print("\n慢帧统计")
    by_page = {}
    by_loading = {True: 0, False: 0}
    for frame in slow:
        by_page.setdefault(frame["page"], []).append(frame["ms"])
        by_loading[frame["loading"] == "true"] += 1
    for page, values in sorted(by_page.items(), key=lambda item: -len(item[1])):
        values_sorted = sorted(values)
        p95 = values_sorted[min(len(values_sorted) - 1, int(len(values_sorted) * 0.95))]
        print(
            f"  {page:16s} n={len(values):3d}  中位={statistics.median(values):6.0f}ms"
            f"  p95={p95:6.0f}ms  最大={max(values):5d}ms"
        )
    print(f"  慢帧里 loading=true 的：{by_loading[True]}，loading=false 的：{by_loading[False]}")
    if by_loading[False] > 0:
        print("  [!] loading=false 的慢帧 = 纯交互卡顿（不是加载导致的），重点关注")
    else:
        print("  [OK] 慢帧全部发生在加载期间（loading=true）")

    values = [frame["ms"] for frame in slow]
    print(f"  慢帧耗时：中位 {statistics.median(values):.0f}ms  最大 {max(values)}ms  >100ms 的有 {sum(1 for v in values if v > 100)} 个")

    print("\n慢帧明细（最多 40 条）")
    for frame in slow[:40]:
        print(
            "  tick={tick:<7d} {ms:>4d}ms  page={page:<16s} rail={rail:<5s} "
            "loading={loading:<5s} cells={cells}".format(**frame)
        )

    if rails:
        print("\n侧栏动画质量")
        # 按 target 变化切成一次次动画（target 从 1 变成 0 等）
        groups = []
        current = []
        last_target = None
        for rail in rails:
            if last_target is not None and rail["target"] != last_target:
                groups.append(current)
                current = []
            current.append(rail)
            last_target = rail["target"]
        if current:
            groups.append(current)
        for index, group in enumerate(groups, start=1):
            widths = [g["w"] for g in group]
            if len(widths) < 2:
                continue
            deltas = [b - a for a, b in zip(widths, widths[1:])]
            zero_steps = sum(1 for d in deltas if abs(d) < 0.5)
            backwards = sum(1 for d in deltas if d < -0.5) if group[-1]["target"] > group[0]["t"] else sum(
                1 for d in deltas if d > 0.5
            )
            duration = sum(g["dt"] for g in group)
            print(
                f"  #{index} target={group[-1]['target']:.0f}  帧数={len(group)}  时长≈{duration:.0f}ms  "
                f"宽度 {widths[0]:.0f}→{widths[-1]:.0f}  停顿帧={zero_steps}  反向={backwards}"
            )
            if zero_steps * 2 > len(deltas):
                print("       [!] 超过一半的帧宽度没变化 —— 动画被别的活挡住了")
            if backwards > 0:
                print("       [!] 出现反向跳变 —— 动画被外部打断/重置")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", default=LOG_PATH, help="日志路径")
    parser.add_argument("--all", action="store_true", help="分析所有会话")
    parser.add_argument("--tail", type=int, default=0, help="只看最后 N 行")
    args = parser.parse_args()

    sessions = read_sessions(args.log)
    if args.tail > 0:
        with open(args.log, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()[-args.tail:]
        sessions = [lines]

    if not sessions:
        print("日志里没有找到 `=== DIAG SESSION START ===`，先运行测试版并手动点几下。")
        sys.exit(1)

    selected = sessions if args.all else sessions[-1:]
    for index, lines in enumerate(selected, start=1):
        frames, rails, marks = parse_session(lines)
        print("=" * 78)
        print(f"会话 {index}（共 {len(selected)}）：{len(lines)} 行")
        print("=" * 78)
        if not frames and not rails:
            print("  这个会话里没有任何 FRAME/RAIL 记录（可能程序刚启动就被关了）")
            continue
        summarize(frames, rails, marks)


if __name__ == "__main__":
    main()
