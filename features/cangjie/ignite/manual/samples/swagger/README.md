# Ignite Swagger Sample

This sample demonstrates a public-ready `0500` path for:

- Swagger / OpenAPI output
- `InterfaceSpec`-driven interface metadata
- `TestOption` and `x-ignite-test`
- debug-only first-run verification gated by `kmode`

Run commands from the repository root containing `cjpm.toml` (current layout: `Ignite/`).

## 1) Run the sample

```bash
./manual/samples/swagger/run.sh
```

Expected startup output includes, by default:

- Swagger UI: `http://127.0.0.1:18811/swagger`
- OpenAPI JSON: `http://127.0.0.1:18811/swagger/json`
- Self-check curl example using `x-ignite-test: mock`

If you set `Config.enablePrintSwaggerUrl = false`, the Swagger routes still exist, but the startup `Swagger UI: ...` line is intentionally suppressed.

## 2) Try the key paths

Read the generated OpenAPI JSON:

```bash
curl -s http://127.0.0.1:18811/swagger/json
```

Trigger a first-run self-check on the health route:

```bash
curl -i -H 'x-ignite-test: mock' http://127.0.0.1:18811/health
```

Send a normal live request to the echo route:

```bash
curl -i -X POST http://127.0.0.1:18811/echo \
  -H 'content-type: application/json' \
  -d '{"name":"ignite"}'
```

Trigger a probe-style self-check on the echo route:

```bash
curl -i -X POST 'http://127.0.0.1:18811/echo?__ignite_test=probe' \
  -H 'content-type: application/json' \
  -d '{"name":"ignite"}'
```

## Notes

- Runtime self-check interception works only when `Config.kmode = true`.
- `enableSwagger` controls whether Swagger UI / JSON routes exist at all.
- `swaggerPath` controls both the UI path and the `/json` OpenAPI path under the same prefix.
- `x-ignite-test` is metadata carried into OpenAPI JSON; it is not a production automation switch.
- The sample is intended for first-run verification, interface understanding, and tooling/AI loading experiments.
