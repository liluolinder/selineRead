# Server Socket Double-Accept Sequential-Connection Experiment

This sample runs the HQ-only `double-accept sequential-connection` loopback proof
for `ignite.server.socket`.

It proves:

- one real local listener
- one first bounded accepted connection
- one second distinct bounded accepted connection
- one honest exit after the second connection

It still does not prove:

- accept loop
- multi-connection scheduler/runtime closure
- `App`
- `Ctx`
- `server_engine`

## Run

```bash
./manual/samples/server_socket_double_accept_experiment/run.sh
```
