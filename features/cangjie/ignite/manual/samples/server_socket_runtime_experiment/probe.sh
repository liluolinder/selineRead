#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

echo "=== Ignite Server Socket Runtime Experiment Probe ==="
echo ""

echo "1. Building..."
cjpm build 2>&1 | tail -5

echo ""
echo "2. Running focused runtime experiment suite..."
cjpm test src/tests --filter SocketHttp11RuntimeExperimentTestSuite --parallel 1 --no-progress 2>&1 | tail -10

echo ""
echo "3. Compiling sample..."
IGNITE_SAMPLE_SKIP_BUILD=1 "${ROOT}/manual/samples/server_socket_runtime_experiment/run.sh"

echo ""
echo "=== Done ==="
