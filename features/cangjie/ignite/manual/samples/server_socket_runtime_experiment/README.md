# Server Socket Runtime Experiment

This sample is the first narrow `server-socket` runtime experiment for `ig0700 -> 0800`.

What it proves:

- one complete HTTP/1.1 request wire can enter the landed parser/session/request-snapshot/writer chain
- a fixed internal responder can produce full response wire bytes
- closeout stays explicit for `keep-alive`, `chunked`, and `close-after-write`
- requests that still require a body-stage handoff are stopped honestly instead of being overclaimed

Run:

```bash
./manual/samples/server_socket_runtime_experiment/run.sh
```

Focused probe:

```bash
./manual/samples/server_socket_runtime_experiment/probe.sh
```
