# Server Socket Count-Limited Accept-Loop Experiment

This sample runs the HQ-only `count-limited accept-loop two-connection` loopback
proof for `ignite.server.socket`.

It proves:

- one real local listener
- one explicit accept loop capped at exactly two accepted connections
- one first bounded accepted connection
- one second bounded accepted connection
- one honest exit because the accepted-connection limit is reached

It still does not prove:

- indefinite accept loop
- multi-connection scheduler/runtime closure
- `App`
- `Ctx`
- `server_engine`

## Run

```bash
./manual/samples/server_socket_count_limited_accept_loop_experiment/run.sh
```

## Probe

```bash
./manual/samples/server_socket_count_limited_accept_loop_experiment/probe.sh
```
