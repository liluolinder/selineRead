#!/bin/bash
# Probe: proxy_transport_acceptance
#
# Usage:
#   cd /path/to/IgniteNEXT
#   ./manual/samples/proxy_transport_acceptance/probe.sh
#
# This probe covers the proxy HTTPS unknown-length upload transport:
#   1. unknown-length https upload -> temp-file buffered fallback (no TLS config)
#   2. maxBufferedBodyBytes exceeded -> local 413
#   3. TlsClientConfig seam bypasses old "TLS must be configured" boundary
#   4. Without TlsClientConfig: old missing-TLS boundary is still reachable
#
# It runs both the broad proof holder and the narrower acceptance suite.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

echo "=== Ignite Transport Acceptance Probe ==="
echo ""

echo "1. Building..."
cjpm build 2>&1 | tail -5

echo ""
echo "2. Running ProxyMiddlewareTestSuite (broad proof holder)..."
cjpm test src/tests --filter ProxyMiddlewareTestSuite --parallel 1 --no-progress 2>&1 | tail -10

echo ""
echo "3. Running ProxyTransportAcceptanceTestSuite (focused acceptance + TlsClientConfig seam)..."
cjpm test src/tests --filter ProxyTransportAcceptanceTestSuite --parallel 1 --no-progress 2>&1 | tail -10

echo ""
echo "=== Done ==="
echo ""
echo "If both suites pass, the current https unknown-length transport answer is re-proven"
echo "and the TlsClientConfig seam is confirmed wired on the HQ mainline."
