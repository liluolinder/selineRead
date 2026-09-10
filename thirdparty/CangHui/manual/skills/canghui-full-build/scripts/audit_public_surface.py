#!/usr/bin/env python3
"""Audit CangHui public documentation, skill metadata, links, and version mirrors."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


SKILL_ROOT = Path(__file__).resolve().parent.parent
MANUAL_SKILLS_ROOT = SKILL_ROOT.parent
DEFAULT_REPOSITORY_ROOT = SKILL_ROOT.parents[2]
TEXT_ENCODINGS = ("utf-8", "utf-8-sig")
LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
INTERNAL_PATTERNS = (
    (re.compile(r"/Users/cinyu(?:/|\b)"), "local user path"),
    (re.compile(r"Cangku.{0,12}_helper", re.IGNORECASE), "internal Cangku helper path"),
    (re.compile(r"(?:^|[\s`/])Cangku/AGENTS\.md(?:$|[\s`])"), "internal project-set entry"),
    (re.compile(r"(?:^|[\s`/])CangHui/_helper(?:$|[/\s`])"), "member helper residue"),
    (re.compile(r"\bISSUE-2026\d+"), "internal issue id"),
    (re.compile(r"\bCK-CANGHUI-\d+"), "internal packet id"),
)
PUBLIC_TEXT_SUFFIXES = {".md", ".cj", ".toml", ".json", ".yaml", ".yml", ".sh", ".py"}


def read_text(path: Path) -> str:
    for encoding in TEXT_ENCODINGS:
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("utf-8", b"", 0, 1, f"cannot decode {path}")


def repository_root(argv: list[str]) -> Path:
    if len(argv) > 2:
        raise ValueError("usage: audit_public_surface.py [repository-root]")
    root = Path(argv[1]).resolve() if len(argv) == 2 else DEFAULT_REPOSITORY_ROOT
    if not (root / "cjpm.toml").is_file() or not (root / "manual").is_dir():
        raise ValueError(f"not a CangHui repository root: {root}")
    return root


def public_text_files(root: Path) -> list[Path]:
    ignored = {".git", "target", "vendor", "_helper"}
    return sorted(
        path for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PUBLIC_TEXT_SUFFIXES
        and not any(part in ignored for part in path.relative_to(root).parts)
    )


def markdown_files(root: Path) -> list[Path]:
    return [path for path in public_text_files(root) if path.suffix.lower() == ".md"]


def link_target(raw: str) -> str:
    value = raw.strip()
    if value.startswith("<") and ">" in value:
        value = value[1:value.index(">")]
    elif " \"" in value:
        value = value.split(" \"", 1)[0]
    return value


def audit_internal_markers(root: Path, errors: list[str]) -> None:
    audit_script = Path(__file__).resolve()
    for path in public_text_files(root):
        if path.resolve() == audit_script:
            continue
        text = read_text(path)
        relative = path.relative_to(root)
        for pattern, label in INTERNAL_PATTERNS:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{relative}:{line}: public text contains {label}")


def audit_markdown_links(root: Path, errors: list[str]) -> None:
    for path in markdown_files(root):
        text = read_text(path)
        relative = path.relative_to(root)
        for match in LINK_PATTERN.finditer(text):
            target = link_target(match.group(1))
            if (not target or target.startswith("#") or target.startswith("/") or
                    re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target)):
                continue
            local = unquote(target.split("#", 1)[0].split("?", 1)[0])
            if not local:
                continue
            resolved = (path.parent / local).resolve()
            try:
                resolved.relative_to(root)
            except ValueError:
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{relative}:{line}: local link escapes repository: {target}")
                continue
            if not resolved.exists():
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{relative}:{line}: missing local link target: {target}")


def toml_package_value(path: Path, key: str) -> str:
    in_package = False
    for line in read_text(path).splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            in_package = stripped == "[package]"
            continue
        if in_package:
            match = re.fullmatch(rf"{re.escape(key)}\s*=\s*\"([^\"]+)\"", stripped)
            if match:
                return match.group(1)
    raise ValueError(f"missing [package].{key} in {path}")


def require_text(path: Path, needle: str, errors: list[str], label: str) -> None:
    if needle not in read_text(path):
        errors.append(f"{path.name}: missing {label}: {needle}")


def audit_version_and_identity(root: Path, errors: list[str]) -> None:
    manifest = root / "cjpm.toml"
    version = toml_package_value(manifest, "version")
    package = toml_package_value(manifest, "name")
    if package != "chui":
        errors.append(f"cjpm.toml: root package must be chui, found {package}")

    require_text(root / "README.md", f"version-{version}-", errors, "version badge")
    require_text(root / "README.zh-CN.md", f"version-{version}-", errors, "version badge")
    require_text(root / "manual/index.md", f"`{version}`", errors, "manual version")
    require_text(root / "manual/CHANGELOG.md", f"## {version} ", errors, "current changelog heading")

    retired_governance_assets = (
        root / "contracts/canghui-capability-matrix.json",
        root / "contracts/canghui-arkui-component-matrix.json",
    )
    for retired in retired_governance_assets:
        if retired.exists():
            errors.append(f"{retired.relative_to(root)}: internal governance matrix must not be public")
    if (root / "docs").exists():
        errors.append("docs/: retired public documentation root must not return; use manual/")

    symbol_source = read_text(root / "src/symbol/symbol.cj")
    expected_symbol = f'SymbolProviderSource("CangHui", "built-in", "{version}"'
    if expected_symbol not in symbol_source:
        errors.append("src/symbol/symbol.cj: built-in provider version does not match cjpm.toml")

    if not (root / "src/chui.cj").is_file() or not (root / "manual/api/chui").is_dir():
        errors.append("public chui source/API roots are missing")
    if (root / "manual/api/cui").exists():
        errors.append("manual/api/cui remains as a live public package root")


def audit_skills(errors: list[str]) -> None:
    skill_files = sorted(MANUAL_SKILLS_ROOT.glob("*/SKILL.md"))
    if not skill_files:
        errors.append("manual skills: no SKILL.md files found")
        return
    for skill_file in skill_files:
        skill_root = skill_file.parent
        text = read_text(skill_file)
        label = f"manual skill {skill_root.name}"
        if not text.startswith("---\n"):
            errors.append(f"{label}: YAML frontmatter is missing")
            continue
        end = text.find("\n---\n", 4)
        if end < 0:
            errors.append(f"{label}: YAML frontmatter is not closed")
            continue
        frontmatter = text[4:end]
        name = re.search(r"^name:\s*([^\s]+)\s*$", frontmatter, re.MULTILINE)
        description = re.search(r"^description:\s*(.+)$", frontmatter, re.MULTILINE)
        if not name or name.group(1) != skill_root.name:
            errors.append(f"{label}: name must match its directory")
        if not description or len(description.group(1).strip()) < 40:
            errors.append(f"{label}: description must state a discriminating use case")


def main(argv: list[str]) -> int:
    try:
        root = repository_root(argv)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    errors: list[str] = []
    audit_internal_markers(root, errors)
    audit_markdown_links(root, errors)
    audit_version_and_identity(root, errors)
    audit_skills(errors)
    if errors:
        print("CangHui public-surface audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("CangHui public-surface audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
