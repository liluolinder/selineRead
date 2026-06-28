# Ignite Sample: handlefortest

这个样例不是普通的 HTTP 功能展示，
而是给 `App.handleForTest(...)` 的并发场景留一个可重复执行的 stress probe。

它关注的是：

- 多个独立进程同时跑 `handleForTest(...)`
- 这些进程共享同一个 lease 根目录
- `handleForTest` 是否还能稳定完成本地监听、请求发送和资源释放

## 运行单个 worker

在仓库根目录执行：

```bash
./manual/samples/handlefortest/run.sh
```

默认会跑一个 worker，做一小批 `GET /ping` 和 `POST /echo` 调用。

## 运行并发 probe

在仓库根目录执行：

```bash
./manual/samples/handlefortest/probe.sh
```

默认会：

- 先编译样例 worker
- 再并发启动多个独立进程
- 让它们共享同一个 `IGNITE_INPROC_TEST_PORT_LEASE_DIR`
- 最后汇总每个 worker 是否成功

## 可选环境变量

- `IGNITE_HANDLE_FOR_TEST_PROBE_WORKERS`
  默认 `6`
- `IGNITE_HANDLE_FOR_TEST_PROBE_ITERATIONS`
  默认 `24`
- `IGNITE_HANDLE_FOR_TEST_PROBE_LEASE_DIR`
  手动指定共享 lease 根目录；默认会落在 `/tmp`
- `IGNITE_HANDLE_FOR_TEST_STRESS_ITERATIONS`
  单独运行 `run.sh` 时控制每个 worker 的循环次数；默认 `8`
- `IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static`
- `IGNITE_CJ_RUNTIME_LIB_DIR=/path/to/cangjie/runtime/lib/<platform>`

## 结果边界

这条 probe 的意义是：

- 证明 `handleForTest` 现在不再只依赖 per-process hashing
- 给 future run 留一个可复用的多进程回归入口

它不代表：

- 已经对整个 `ignite.tests` full-suite 做了更大范围并发收口
- 所有 CI / 宿主机 / 文件系统下的行为都已完全证明
