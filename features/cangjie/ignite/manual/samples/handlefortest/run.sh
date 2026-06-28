#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

export IGNITE_HANDLE_FOR_TEST_STRESS_ID="${IGNITE_HANDLE_FOR_TEST_STRESS_ID:-worker-standalone}"
export IGNITE_HANDLE_FOR_TEST_STRESS_ITERATIONS="${IGNITE_HANDLE_FOR_TEST_STRESS_ITERATIONS:-8}"

"${ROOT}/manual/samples/_shared/run_server_sample.sh" "manual/samples/handlefortest/main.cj" "/tmp/ignite_sample_handlefortest"
