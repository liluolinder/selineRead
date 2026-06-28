# Ignite Sample: files

这个样例现在不只演示传统文件响应，
也把 `ig0600` 这轮已经落地的 payload-path 能力放到了可运行入口里：

- `sendFile(...)`
- `download(...)`
- `sendFileRange(...)`
- `sendStream(...)`
- `saveBodyToFile(...)`

## 运行

在仓库根目录执行：

```bash
./manual/samples/files/run.sh
```

默认监听：

```text
http://127.0.0.1:18812
```

## 路由

- `GET /view`
  直接返回样例文本文件
- `GET /download`
  以附件形式下载样例文本文件
- `GET /range`
  演示 Range 响应
- `GET /stream-known`
  用 `ctx.sendStream(...)` 返回已知长度文本流
- `GET /stream-unknown`
  用 `ctx.sendStream(...)` 返回未知长度文本流
- `POST /push-upload`
  用 `ctx.saveBodyToFile(...)` 把请求体直接落到 `/tmp/ignite_sample_files_upload.txt`
- `GET /uploaded`
  查看最近一次 `/push-upload` 落盘结果

## 试跑命令

```bash
curl -i http://127.0.0.1:18812/view
curl -i http://127.0.0.1:18812/download
curl -i -H 'Range: bytes=0-63' http://127.0.0.1:18812/range
curl -i http://127.0.0.1:18812/stream-known
curl -i http://127.0.0.1:18812/stream-unknown
printf 'ignite-upload-demo' | curl -i -X POST --data-binary @- http://127.0.0.1:18812/push-upload
curl -i http://127.0.0.1:18812/uploaded
```

## 结果边界

这条 sample 的目标是让维护者能从可运行路径直接感受到：

- 已知长度流响应和未知长度流响应的公开用法
- 大 body 直推文件的最小落地写法
- 文件响应和流响应可以放在同一个服务里共同验证

它不代表：

- H2 on-wire streaming 已经在当前工作区收口
- `https` unknown-length upstream relay 已经有新的 transport-level 解法
