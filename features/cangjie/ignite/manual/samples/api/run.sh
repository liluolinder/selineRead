#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
"${ROOT}/manual/samples/_shared/run_server_sample.sh" "manual/samples/api/main.cj" "/tmp/ignite_sample_api"
