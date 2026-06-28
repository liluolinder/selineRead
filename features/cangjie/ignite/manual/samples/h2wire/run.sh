#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
"${ROOT}/manual/samples/_shared/run_server_sample.sh" "manual/samples/h2wire/main.cj" "/tmp/ignite_sample_h2wire"
