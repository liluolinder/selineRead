# Ignite Sample: ignitekit

`IgniteKit` 示例，展示如何把“动态生成的 HTML/CSS 资源”从主业务路由中剥离：

- `IgniteKit(prefix: "/web")`
- `kit.css("/app.css", "...")` 注册 CSS
- `kit.html("/index.html", template, vars)` 注册模板化 HTML
- `kit.dynamicHtml("/hello.html", renderer)` 注册按请求动态渲染页面
- `kit.mount(app)` 一次性映射到 Ignite 路由

## 运行

在仓库根目录执行：

```bash
./manual/samples/ignitekit/run.sh
```

## 快速验证

```bash
curl -i http://127.0.0.1:18810/web/index.html
curl -i "http://127.0.0.1:18810/web/hello.html?name=ignite"
curl -i http://127.0.0.1:18810/web/app.css
```

## 环境变量（仅在自动探测失败时）

- `IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static`
- `IGNITE_CJ_RUNTIME_LIB_DIR=/path/to/cangjie/runtime/lib/<platform>`
