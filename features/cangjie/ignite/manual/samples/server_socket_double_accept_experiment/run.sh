#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

exec "${ROOT}/manual/samples/_shared/run_server_sample.sh" \
  "manual/samples/server_socket_double_accept_experiment/main.cj" \
  "/tmp/ignite_sample_server_socket_double_accept_experiment"
