# Server Socket Accept-Once Experiment

This sample runs the HQ-only `accept-one / serve-once` loopback proof for
`ignite.server.socket`.

It proves one real local listener/client turn without touching:

- `App`
- `Ctx`
- `server_engine`
- accept loop

Current honesty line:

- the experiment always closes after one served turn
- that close is owned by the experiment itself
- it does not prove keep-alive multi-turn runtime closure

## Run

```bash
./manual/samples/server_socket_accept_once_experiment/run.sh
```
