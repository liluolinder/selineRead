---
name: canghui-agent-ui
description: Implement or review a CangHui consumer UI with direct chui dependency boundaries, composable Row alignment, intrinsic controls, and cuic ASCII/pixel evidence before platform screenshots.
---

# CangHui Agent UI

Use this skill when an agent builds or reviews product UI on CangHui Multiplatform. It is a consumer workflow,
not authority to edit the CangHui framework, dependency cache, sibling repositories, or platform host.

## Mandatory read order

1. `manual/index.md`
2. `manual/getting-started/agent-first-workflow.md`
3. `manual/getting-started/sdk-consumption.md`
4. `manual/guide/how-to/agent-ui-review.md`
5. the one task guide and API page directly needed by the change

Stop if the consumer's registered framework version, `cjpm.lock`, and installed `cuic version` disagree. Report
the mismatch instead of changing framework source or a CJPM cache behind the application owner's back.

## Preflight

Run from the consumer root and record the real results:

```bash
cuic version
cuic doctor <platform> .
cuic build <platform> .
cuic test <platform> .
```

The default dependency is `chui` pinned by `commitId` and `cjpm.lock`. Use a local CangHui path only when the
task explicitly owns framework development or an offline source checkout.

## Layout rules

- Use `Row` for leading/content/trailing information and apply `.layoutWeight()` to the middle content. Do not
  approximate semantic ownership with equal distribution.
- An exact `.width(...)` in `Row`/`HStack` and exact `.height(...)` in `VStack` removes that child from the
  corresponding flex pass. Do not insert a `Spacer` to compensate for an unexpected empty slot; update to
  `chui >= 0.16.1` and verify the actual assigned rectangles first.
- Let `Button` and `IconButton` keep intrinsic height. Add `.fillHeight()` only when the design explicitly asks
  for a full-height control, and mention that choice in the receipt.
- The regular Button baseline is 38 vp. In a dense desktop toolbar or sidebar, opt into a compact target
  explicitly with `.minControlSize(width: 0.0, height: 28.0)` and retain readable horizontal
  `contentPadding`; do not let a product-wide dense surface silently inherit the regular baseline.
- Preserve readable padding; do not make a text-tight button. Use `contentPadding` intentionally for slot
  buttons.
- Use `Icon`, `IconButton`, or generated `Symbol`; do not rely on emoji, text glyphs, or iconfont metrics.
- Use `ButtonStyle.quiet()` for dense icon-command rows that should not show idle field borders. Do not replace
  an available icon with a text button merely because the command name is easier to type.
- A custom `ButtonStyle` must derive foreground and Ink from the active theme. For an accent surface use
  `theme.accentText` / `theme.inkColor(role: role)`; never hardcode white merely because one theme uses a dark
  accent.
- For letter avatars or square icon labels, set `Label.textAlign(TextAlign.Center)` explicitly; fixed frame size
  alone centers vertically but does not change the default leading text alignment.
- For a synchronized line-number gutter, use an exact width and `TextArea(..., editable: false,
  chrome: TextAreaChrome.None)`; do not paint a second input-field border around the gutter.
- Use `FlowRow` for variable chips in narrow sidebars and one state-derived theme across every surface.
- Keep title, supporting text, trailing state, and action visually distinct; move long explanation to details/help.

## Evidence order

Prefer deterministic framework evidence before OS capture:

```bash
cuic shell snapshot .
cuic pview . <probe-id> --columns 96 --rows 32
cuic prnt <platform> . --output artifacts/ui.png
```

Use `cuic shell click . <x> <y>` or `cuic shell focus . <id>` only when runtime interaction must be
replayed. This launches a bounded one-shot debug child, prints semantic state, and exits; it never attaches to an
arbitrary running process or opens a listener. Use `cuic shell run . --events '<commands>'` for a short sequence,
then `snapshot`/`diff`; commands are a fixed UI-event whitelist, not shell text.

`cuic probe ascii` is the pview alias. Shell/probe/pview execution requires a debug cuic; release refusal is expected.
If no probe exists, add stable semantics for the changed view before claiming layout acceptance.

Use an OS or device screenshot only for platform chrome, IME, native menus, system composition, or device-host
integration. It supplements, never replaces, pview/probe and framework capture.

## Acceptance

Check narrow/common/wide viewports and light/dark themes. Return: exact source changes, build/test commands,
ASCII observations, pixel observations when visual output changed, interaction evidence, and every platform/device
gate not replayed. Do not call a screenshot-only review complete.
