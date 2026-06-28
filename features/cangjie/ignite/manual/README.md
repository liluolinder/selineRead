# Ignite Manual

`manual/` 是当前仓库的公开文档中枢，用来承接根 README 之后的正文与样例说明。

## 推荐阅读顺序

1. [`../README.md`](../README.md)
2. [`docs-md/README.md`](docs-md/README.md)
3. [`samples/README.md`](samples/README.md)
4. [`../CHANGELOG.MD`](../CHANGELOG.MD) / [`../CHANGELOG-en.MD`](../CHANGELOG-en.MD)

## 各入口负责什么

- 根 `README.md`：项目门面、价值主张、平台口径、总入口分流。
- `manual/docs-md/`：`0500` 中文正文主入口，也是后续 `docs-web` 的内容源稿。
- `manual/samples/`：可运行路径，帮助你按顺序验证 Ignite 的公开能力。
- `CHANGELOG*`：阶段时间线、版本收口与公开变动记录。

## 公开边界

- `manual/` 只放公开面向的文档，不承接归档实验、维护者私有流程或 `_helper` 内部材料。
- 如果公开表达和内部表达不同，以根 README、`manual/` 与 `CHANGELOG*` 为准。
- 本目录不负责定义新的技术承诺，只负责把当前已经公开确认的能力讲清楚。

## docs-md 与 docs-web 的关系

- `docs-md` 是正文源。
- `docs-web` 是后续的网站呈现层。
- 网站内容以后直接从 `docs-md` 抽取，不再反向定义 `docs-md` 的章节结构。
