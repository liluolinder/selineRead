#!/usr/bin/env python3
"""C45: Inject @throws doc annotations on public funcs that throw.

Usage:
    python3 scripts/c45_throws_annotator.py          # dry-run
    python3 scripts/c45_throws_annotator.py --apply   # apply changes
    python3 scripts/c45_throws_annotator.py --file=ecc --apply  # single file
"""

import os
import re
import sys

SOURCE_DIR = "/Users/cinyu/Documents/Work0/CureateX/Cangku/JinguiSSL-core/src/jinguissl_core"

# Match public func declaration WITH its opening brace
FUNC_PATTERN = re.compile(
    r'(public\s+(?:func|init)\s+\w+\s*\([^)]*\)[^{]*\{)',
    re.DOTALL,
)

HAS_THROWS_TAG = re.compile(r'@throws\s')
DOC_COMMENT_CLOSE = re.compile(r'/\*\*.*?\*/', re.DOTALL)
DOC_COMMENT_OPEN = re.compile(r'/\*\*')


def find_preceding_doc(text: str, pos: int) -> str:
    """Look backwards from pos to find a doc comment."""
    # Skip whitespace backwards
    i = pos - 1
    while i >= 0 and text[i] in ' \t\n\r':
        i -= 1

    # Check for */
    if i >= 0 and text[i-1:i+1] == '*/':
        # Find opening /**
        j = text.rfind('/**', 0, i)
        if j >= 0:
            # Only take it if no non-comment code between
            between = text[j:i+1]
            # Check the between doesn't contain code (no { } ; )
            if '\n' in between or ' ' in between:
                return text[j:i+1]
    return ""


def get_braced_body(text: str, start: int) -> str:
    """Extract body from { at start to matching }."""
    depth = 1
    pos = start + 1
    while depth > 0 and pos < len(text):
        c = text[pos]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
        pos += 1
    return text[start:pos]


def find_missing_throws(filepath: str):
    """Yield (line_no, func_name, doc, decl_text, brace_pos)."""
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()

    for m in FUNC_PATTERN.finditer(text):
        full_decl = m.group(1)
        brace_pos = m.start(1) + full_decl.rfind('{')

        # Extract func name
        name_m = re.search(r'(?:func|init)\s+(\w+)', full_decl)
        func_name = name_m.group(1) if name_m else "?"

        # Get body
        body = get_braced_body(text, brace_pos)

        if 'throw ' not in body and 'throw(' not in body:
            continue

        # Look for preceding doc comment
        doc = find_preceding_doc(text, m.start())

        if HAS_THROWS_TAG.search(doc):
            continue

        line_no = text[:m.start()].count("\n") + 1
        yield (line_no, func_name, doc, full_decl, brace_pos)


def make_doc(name: str, is_init: bool) -> str:
    if is_init:
        return f"/**\n * 初始化 {name}.\n *\n * @throws CryptoException 当操作失败时抛出\n */\n"
    return f"/**\n * {name}.\n *\n * @throws CryptoException 当操作失败时抛出\n */\n"


def dry_run(filepath: str) -> int:
    changes = list(find_missing_throws(filepath))
    rel = os.path.relpath(filepath, SOURCE_DIR)
    if changes:
        print(f"\n--- {rel} ({len(changes)} funcs) ---")
        for line, name, doc, *_ in changes:
            has = "yes" if doc else "no"
            print(f"  L{line}: public {name} (doc: {has})")
    return len(changes)


def apply_annotations(filepath: str) -> int:
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()

    insertions = []
    for m in FUNC_PATTERN.finditer(text):
        full_decl = m.group(1)
        brace_pos = m.start(1) + full_decl.rfind('{')

        name_m = re.search(r'(?:func|init)\s+(\w+)', full_decl)
        func_name = name_m.group(1) if name_m else "?"
        is_init = " init " in full_decl or full_decl.startswith("init ")

        body = get_braced_body(text, brace_pos)

        if 'throw ' not in body and 'throw(' not in body:
            continue

        doc = find_preceding_doc(text, m.start())
        if HAS_THROWS_TAG.search(doc):
            continue

        if doc:
            # Add @throws before */
            close_idx = text.rfind('*/', m.start() - len(doc) - 5, m.start())
            if close_idx > 0:
                # Find indent
                line_st = text.rfind('\n', 0, close_idx) + 1
                indent = text[line_st:close_idx]
                indent = indent[:len(indent) - len(indent.lstrip())]
                insertions.append((close_idx, f"\n{indent} * @throws CryptoException 当操作失败时抛出"))
        else:
            insertions.append((m.start(), make_doc(func_name, is_init)))

    if not insertions:
        return 0

    insertions.sort(key=lambda x: x[0], reverse=True)
    text_list = list(text)
    for pos, content in insertions:
        for i, ch in enumerate(content):
            text_list.insert(pos + i, ch)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write("".join(text_list))

    return len(insertions)


def main():
    apply = "--apply" in sys.argv
    only_file = None
    for arg in sys.argv[1:]:
        if arg.startswith("--file="):
            only_file = arg.split("=", 1)[1]

    total = 0
    file_count = 0

    for root, dirs, files in os.walk(SOURCE_DIR):
        dirs[:] = [d for d in dirs if d not in ("tests", "compat")]
        for fname in files:
            if not fname.endswith(".cj") or fname.endswith("_test.cj"):
                continue
            fpath = os.path.join(root, fname)
            if only_file and only_file not in fpath:
                continue

            if apply:
                c = apply_annotations(fpath)
                if c:
                    file_count += 1
                    total += c
                    print(f"  {os.path.relpath(fpath, SOURCE_DIR)}: {c}")
            else:
                c = dry_run(fpath)
                if c:
                    file_count += 1
                    total += c

    if apply:
        print(f"\n✅ Applied: {total} @throws annotations across {file_count} files")
    else:
        print(f"\n📋 Dry-run: {total} functions missing @throws across {file_count} files")


if __name__ == "__main__":
    main()
