# Server Socket Keep-Alive Two-Turn Experiment

This sample runs the HQ-only `single-connection keep-alive two-turn` loopback proof
for `ignite.server.socket`.

It proves:

- one real local listener
- one accepted client connection
- two sequential request/response turns on the same connection
- one bounded close after the second turn

It still does not prove:

- accept loop
- multi-connection runtime
- `App`
- `Ctx`
- `server_engine`

## Run

```bash
./manual/samples/server_socket_keepalive_two_turn_experiment/run.sh
```
