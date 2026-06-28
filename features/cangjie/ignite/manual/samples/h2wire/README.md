# Ignite Sample: h2wire

最小 H2 on-wire smoke 样例，专门用来验证两件事：

- `ctx.writer()` 在 TLS + ALPN 的 H2 路径下可以多次写出响应体
- `sendFile(...)` 的大文件返回在 H2 路径下不依赖 `Transfer-Encoding`
- 一旦本地 TLS/provider 路线稳定下来，可以直接挂上 `h2spec` 做额外 conformance smoke

## 运行服务

在仓库根目录执行：

```bash
./manual/samples/h2wire/run.sh
```

如果你本地正好就是当前 Ignite 工作区，并且 `_helper/testdata/tls/server-cert-a.pem` / `server-key-a.pem` 存在，样例会默认使用它们。
否则请先设置：

```bash
export IGNITE_SAMPLE_TLS_CERT=/path/to/server-cert.pem
export IGNITE_SAMPLE_TLS_KEY=/path/to/server-key.pem
```

启动后可手动验证：

```bash
curl -k --http2 -i https://127.0.0.1:18444/
curl -k --http2 -i https://127.0.0.1:18444/health
curl -k --http2 -N https://127.0.0.1:18444/stream
curl -k --http2 -D - -o /tmp/ignite_h2_wire.out https://127.0.0.1:18444/file
```

## 一键 probe

如果你想直接跑本地 smoke：

```bash
./manual/samples/h2wire/probe.sh
```

如果你只想快速看旧 `GeneralPrivateKey.decodeFromPem(...)` diagnostic
是不是跟 key 形态相关，可以执行：

```bash
./manual/samples/h2wire/guard_matrix.sh
```

这条脚本会自动生成传统 RSA PEM（PKCS#1）副本，并对下面 4 个 case 只跑 `legacy_key_decode` diagnostic：

- `key-a:pkcs8`
- `key-b:pkcs8`
- `key-a:pkcs1`
- `key-b:pkcs1`

输出只保留 case 结果与简短诊断，适合做本地 TLS 阻塞的快速复验。

这个 probe 会：

1. 编译当前仓的 Ignite 与样例程序
2. 先用一个隔离的 TLS guard 进程探测 `precheck -> cert decode -> mainline TLS build` 这条路径
   这条 guard 现在默认拆成三段顺序探测：
   - `precheck`
   - `cert decode`
   - `mainline build`
   legacy `key_decode` 仍保留，但只作为显式 diagnostic，不再是默认 staged path。
3. 如果 guard 通过，再启动一个本地 TLS 服务，并先等待 listener-ready banner
4. 然后再用 health probe / Node 内建 `http2` 客户端验证：
   - ALPN 结果确实是 `h2`
   - `/stream` 没有 `Transfer-Encoding`
   - `/stream` 是多次 data event 到达，而不是单次整包
   - `/file` 没有 `Transfer-Encoding`
   - `/file` 的大响应体大小与 `content-length` 一致

如果默认 guard 阶段就失败，说明当前 mainline-aligned TLS load path 还没有通过。
如果 listener-ready banner 都没出现，并且 log 里带 `LISTEN_PERMISSION_DENIED`，那更像沙箱/宿主 bind 噪声，不是 TLS handshake blocker。
如果 listener-ready banner 已出现，但第一次 `/health` TLS 握手就把服务打崩，那么当前更深 blocker 会继续缩到 `stdx.net.tls.TlsContext.createContext()` 这条 runtime seam。
legacy `key_decode` diagnostic 仍然有用，但它现在只回答“旧 decode seam 会不会因为 key 形态不同而崩”，不再代表当前 mainline listener path。
这条 smoke 路线当前保留下来的价值，正是把“本地 H2 on-wire 没闭”从口头判断变成分阶段、可重复的失败证据。

## h2spec smoke

如果你本地已经装了 `h2spec`，并且 TLS/provider 路线已稳定，可以执行：

```bash
./manual/samples/h2wire/h2spec_smoke.sh
```

这条脚本会：

1. 先复用当前 `probe.sh` 的 staged TLS guard（默认不跳过）
2. 再单独拉起 `h2wire` sample 服务
3. 用 `h2spec` 对目标地址跑一组可配置的 smoke case

当前默认只跑：

```text
generic
```

这样做的目的不是“现在就宣称 H2 已完全收口”，而是：

- 把将来的 conformance 工位先接到样例上
- 让后续稳定 TLS/provider 路线出现后，可以直接补跑 `h2spec`

如果你现在只是想检查 staged 命令长什么样，而不是立即执行：

```bash
IGNITE_H2SPEC_PREPARE_ONLY=1 ./manual/samples/h2wire/h2spec_smoke.sh
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `IGNITE_SAMPLE_TLS_CERT` | `_helper/testdata/tls/server-cert-a.pem` | TLS 证书路径 |
| `IGNITE_SAMPLE_TLS_KEY` | `_helper/testdata/tls/server-key-a.pem` | TLS 私钥路径 |
| `IGNITE_H2_FIXTURE_MULTIPLIER` | `64` | 响应体大小 = 4096 × 51B × multiplier。默认约 13 MiB |
| `IGNITE_SAMPLE_WRITE_TIMEOUT_SECS` | `30` | 服务端 writeTimeout 值（秒） |
| `IGNITE_STDX_STATIC` | 自动探测 | 指向 `cj_stdx_*_llvm/static` |
| `IGNITE_CJ_RUNTIME_LIB_DIR` | 自动探测 | 指向 Cangjie 运行时动态库目录 |
| `IGNITE_H2_TLS_GUARD_STAGES` | `precheck,cert_decode,mainline_build` | TLS guard 阶段控制；`legacy_key_decode` 仅作显式 diagnostic |
| `IGNITE_H2_TLS_GUARD_ONLY` | `0` | 仅跑 guard，不启动服务 |
| `IGNITE_H2SPEC_BIN` | `h2spec` | h2spec 二进制路径 |
| `IGNITE_H2SPEC_SPECS` | `generic` | h2spec 要跑的 case 列表 |
| `IGNITE_H2SPEC_SKIP_GUARD` | `0` | 跳过 guard 直接起服务 |
| `IGNITE_H2SPEC_HOST` | `127.0.0.1` | h2spec 目标地址 |
| `IGNITE_H2SPEC_PORT` | `18444` | h2spec 目标端口 |
| `IGNITE_H2SPEC_PREPARE_ONLY` | `0` | 只打印 h2spec 命令，不实际执行 |
| `IGNITE_H2SPEC_STRICT` | `0` | h2spec strict mode |
| `IGNITE_H2SPEC_DRYRUN` | `0` | 只展示 h2spec case 列表 |
| `IGNITE_STALL_DELAY_MS` | `35000` | stall 验证器：single 模式下客户端延迟读取的时间（ms） |
| `IGNITE_STALL_PATH` | `/file` | stall 验证器：single 模式下请求路径 |
| `IGNITE_STALL_CONCURRENCY` | `1` | stall 验证器：并发延迟请求数 |
| `IGNITE_STALL_PRECONNECT` | `true` | stall 验证器：测试前预热连接 |
| `IGNITE_STALL_VERBOSE` | `false` | stall 验证器：打印每个请求的详细结果 |
| `IGNITE_STALL_ABORT_TIMEOUT_MS` | `60000` | stall 验证器：整体安全超时 |
| `IGNITE_STALL_MODE` | `matrix` | stall 验证器：`matrix` 或 `single` |
| `IGNITE_STALL_MATRIX_SHORT_MS` | `5000` | stall 验证器：matrix 模式下的短延迟 |
| `IGNITE_STALL_MATRIX_LONG_MS` | `35000` | stall 验证器：matrix 模式下的长延迟 |

## H2 WINDOW_UPDATE Stall 验证

新增的 `verify_window_update_stall.mjs` 用于有界复现 H2 大响应在客户端延迟读取时的 WINDOW_UPDATE stall / write-timeout 行为。
脚本默认跑一个小矩阵，也支持 `single` 模式精确指定 `path + delay + concurrency`。

原理：
1. 发送 HTTP/2 请求到 `/file` 或 `/stream`
2. 客户端在指定时长内先 `pause()` 响应流，模拟浏览器处理其他流时的延迟
3. 内部缓冲区填满后，HTTP/2 流控停止发送 `WINDOW_UPDATE`
4. 服务端写满初始窗口后等待 `WINDOW_UPDATE`，与此同时 writeTimeout 计时器在走
5. 超过 writeTimeout 后服务端关闭流（`ProtocolError`）
6. 延迟结束后注册 data handler 并消费数据，观察流是恢复还是已终止

运行方式（需先启动 h2wire 服务）：

```bash
# 先启动服务
IGNITE_SAMPLE_WRITE_TIMEOUT_SECS=30 IGNITE_H2_FIXTURE_MULTIPLIER=64 ./manual/samples/h2wire/run.sh &
# 等待就绪后，运行 stall 验证器
node manual/samples/h2wire/verify_window_update_stall.mjs
```

单次精确场景：

```bash
IGNITE_STALL_MODE=single \
IGNITE_STALL_PATH=/file \
IGNITE_STALL_DELAY_MS=40000 \
IGNITE_STALL_CONCURRENCY=4 \
node manual/samples/h2wire/verify_window_update_stall.mjs
```

典型矩阵：

| 场景 | writeTimeout | 延迟 | 预期 |
|------|-------------|------|------|
| `/file` baseline（无延迟） | 30s | 0ms | 完成 |
| `/file` 延迟 > 30s | 30s | 35000ms | write timeout 触发 |
| `/stream` baseline（无延迟） | 30s | 0ms | 完成 |
| `/stream` 延迟 > 30s | 30s | 35000ms | write timeout 触发 |
| `/file` 延迟 < 超时 | 45s | 40000ms | 完成（客户端恢复读取） |
