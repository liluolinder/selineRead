# Ignite Sample: api

内存 Todo CRUD 示例，展示：

- 路由参数：`/todos/:id`
- 查询参数：`?done=true|false`、`?title=...`
- `ctx.jsonEncode(...)` 输出 JSON
- `ctx.jsonEncodeStream(...)` 可用于实现 `JsonWriterEncodable` 的对象，避免先构造完整 JSON 字符串；当前 sample 保持 `ctx.jsonEncode(...)` 以展示普通 CRUD 路径

## 路由

- `GET /todos`：列表
- `GET /todos?done=true`：按状态过滤
- `POST /todos?title=foo`：创建
- `GET /todos/:id`：详情
- `PATCH /todos/:id?done=true`：更新状态
- `DELETE /todos/:id`：删除

## 运行

在仓库根目录执行：

```bash
./manual/samples/api/run.sh
```

## 快速验证

```bash
curl -i "http://127.0.0.1:18809/todos"
curl -i -X POST "http://127.0.0.1:18809/todos?title=learn-ignite"
curl -i "http://127.0.0.1:18809/todos/1"
curl -i -X PATCH "http://127.0.0.1:18809/todos/1?done=true"
curl -i "http://127.0.0.1:18809/todos?done=true"
curl -i -X DELETE "http://127.0.0.1:18809/todos/1"
```

## 环境变量（仅在自动探测失败时）

- `IGNITE_STDX_STATIC=/path/to/cj_stdx_*_llvm/static`
- `IGNITE_CJ_RUNTIME_LIB_DIR=/path/to/cangjie/runtime/lib/<platform>`
