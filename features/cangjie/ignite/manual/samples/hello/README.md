# Ignite Sample: hello

最简服务样例，包含：

- `GET /` 返回纯文本
- `GET /health` 返回 JSON

## 运行

在仓库根目录执行：

```bash
./manual/samples/hello/run.sh
```

启动后可用以下命令验证：

```bash
curl -i http://127.0.0.1:18808/
curl -i http://127.0.0.1:18808/health
```

## 环境变量（仅在自动探测失败时）

- `IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static`
- `IGNITE_CJ_RUNTIME_LIB_DIR=/path/to/cangjie/runtime/lib/<platform>`
