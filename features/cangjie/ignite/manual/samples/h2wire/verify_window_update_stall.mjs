#!/usr/bin/env node
/**
 * verify_window_update_stall.mjs
 *
 * Bounded H2 / WINDOW_UPDATE stall / write-timeout verifier.
 *
 * Strategy:
 * 1. Connect to the Ignite h2wire sample via HTTP/2 (TLS)
 * 2. Send one or more requests for a large fixture (/file or /stream)
 * 3. Pause each response stream to simulate a delayed reader
 * 4. After a configurable delay, resume reading
 * 5. Record whether the stream completed successfully or timed out
 *
 * Environment knobs:
 *   IGNITE_STALL_DELAY_MS             - Delay before resume for single-case mode
 *   IGNITE_STALL_PATH                 - Request path for single-case mode
 *   IGNITE_STALL_CONCURRENCY          - Number of concurrent delayed requests
 *   IGNITE_STALL_PRECONNECT           - Pre-create session before requests
 *   IGNITE_STALL_VERBOSE              - Print per-request details
 *   IGNITE_STALL_ABORT_TIMEOUT_MS     - Overall safety timeout per request
 *   IGNITE_STALL_MODE                 - `matrix` (default) or `single`
 *   IGNITE_STALL_MATRIX_SHORT_MS      - Matrix baseline resume delay under timeout
 *   IGNITE_STALL_MATRIX_LONG_MS       - Matrix resume delay over default timeout
 */

import http2 from "node:http2";
import { performance } from "node:perf_hooks";

const BASE_URL = "https://127.0.0.1:18444";
const DEFAULT_DELAY_MS = Number(process.env.IGNITE_STALL_DELAY_MS ?? "35000");
const DEFAULT_PATH = process.env.IGNITE_STALL_PATH ?? "/file";
const CONCURRENCY = Number(process.env.IGNITE_STALL_CONCURRENCY ?? "1");
const PRECONNECT = (process.env.IGNITE_STALL_PRECONNECT ?? "true") === "true";
const VERBOSE = (process.env.IGNITE_STALL_VERBOSE ?? "false") === "true";
const STALL_ABORT_TIMEOUT_MS = Number(process.env.IGNITE_STALL_ABORT_TIMEOUT_MS ?? "60000");
const STALL_MODE = process.env.IGNITE_STALL_MODE ?? "matrix";
const MATRIX_SHORT_MS = Number(process.env.IGNITE_STALL_MATRIX_SHORT_MS ?? "5000");
const MATRIX_LONG_MS = Number(process.env.IGNITE_STALL_MATRIX_LONG_MS ?? "35000");

function stallRequest(path, delayMs) {
  return new Promise((resolve) => {
    const session = http2.connect(BASE_URL, {
      rejectUnauthorized: false,
      ALPNProtocols: ["h2"],
    });

    let startTs = performance.now();
    let resolved = false;
    let dataReceived = 0;
    let dataChunks = 0;
    let firstDataAt = null;
    let lastDataAt = null;
    let endedOk = false;
    let abortReason = null;
    let statusCode = null;
    let headers = {};

    const req = session.request({
      ":method": "GET",
      ":path": path,
    });

    let finish = (event) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(safetyTimer);
      const elapsed = performance.now() - startTs;
      const alpn = session.socket?.alpnProtocol ?? "";
      session.close();
      resolve({
        path,
        delayMs,
        statusCode,
        dataReceived,
        dataChunks,
        firstDataAt,
        lastDataAt,
        elapsedMs: Math.round(elapsed),
        endedOk,
        event,
        abortReason,
        alpn,
        headers,
      });
    };

    session.on("error", (err) => {
      abortReason = err.message;
      finish("session-error");
    });

    req.on("response", (responseHeaders) => {
      headers = responseHeaders;
      statusCode = responseHeaders[":status"];
      req.pause();
      setTimeout(() => {
        req.resume();
      }, delayMs);
    });

    req.on("data", (chunk) => {
      const now = performance.now();
      if (firstDataAt === null) firstDataAt = now;
      lastDataAt = now;
      dataReceived += chunk.length;
      dataChunks++;
    });

    req.on("end", () => {
      endedOk = true;
      finish("end");
    });

    req.on("error", (err) => {
      abortReason = err.message;
      finish("error");
    });

    const safetyTimer = setTimeout(() => {
      if (!resolved) {
        abortReason = `safety-timeout-${STALL_ABORT_TIMEOUT_MS}ms`;
        req.destroy();
        finish("safety-timeout");
      }
    }, STALL_ABORT_TIMEOUT_MS + delayMs + 5000);

    req.end();
  });
}

async function runTest(label, path, delayMs) {
  console.log(`\n--- Test: ${label} ---`);
  console.log(`  path=${path}  delay=${delayMs}ms`);

  const results = await Promise.all(
    Array.from({ length: CONCURRENCY }, () => stallRequest(path, delayMs)),
  );
  if (VERBOSE) {
    for (const r of results) {
      console.log(JSON.stringify(r, null, 2));
    }
  }

  for (const r of results) {
    console.log(
      `  request: ${r.path} delay=${r.delayMs}ms → ` +
        `status=${r.statusCode} bytes=${r.dataReceived} ` +
        `endedOk=${r.endedOk} event=${r.event} ` +
        `abortReason=${r.abortReason ?? "none"} ` +
        `elapsed=${r.elapsedMs}ms`
    );
  }

  const allOk = results.every((r) => r.endedOk && r.statusCode === 200);
  const anyError = results.some((r) => !r.endedOk);
  console.log(`  => ${allOk ? "PASS (all completed)" : anyError ? "STALL/HIT (write timeout triggered)" : "MIXED"}`);
  return { label, path, delayMs, results, allOk, anyError };
}

async function main() {
  console.log("==================================================");
  console.log("  H2 WINDOW_UPDATE Stall / Write-Timeout Verifier");
  console.log("==================================================");
  console.log(`  base_url=${BASE_URL}`);
  console.log(`  mode=${STALL_MODE}`);
  console.log(`  single_path=${DEFAULT_PATH}`);
  console.log(`  single_delay=${DEFAULT_DELAY_MS}ms`);
  console.log(`  concurrency=${CONCURRENCY}`);
  console.log(`  preconnect=${PRECONNECT}`);

  if (PRECONNECT) {
    const warmupSession = http2.connect(BASE_URL, {
      rejectUnauthorized: false,
      ALPNProtocols: ["h2"],
    });
    const warmReq = warmupSession.request({ ":method": "GET", ":path": "/health" });
    await new Promise((resolve) => {
      warmReq.on("end", resolve);
      warmReq.resume();
      warmReq.end();
    });
    warmupSession.close();
    console.log(`  warmup: connected OK`);
  }

  if (STALL_MODE === "single") {
    await runTest("single-case", DEFAULT_PATH, DEFAULT_DELAY_MS);
  } else {
    await runTest("file-no-delay-baseline", "/file", 0);
    await runTest("file-delay-under-timeout", "/file", MATRIX_SHORT_MS);
    await runTest("file-delay-over-timeout", "/file", MATRIX_LONG_MS);
    await runTest("stream-no-delay-baseline", "/stream", 0);
    await runTest("stream-delay-over-timeout", "/stream", MATRIX_LONG_MS);
  }

  console.log("\n==================================================");
  console.log("  Matrix Complete");
  console.log("==================================================");
  console.log("  To test with longer write timeout, restart server with:");
  console.log("    IGNITE_SAMPLE_WRITE_TIMEOUT_SECS=45 IGNITE_H2_FIXTURE_MULTIPLIER=64");
  console.log("  Then run with:");
  console.log("    IGNITE_STALL_MODE=single IGNITE_STALL_PATH=/file IGNITE_STALL_DELAY_MS=40000 node manual/samples/h2wire/verify_window_update_stall.mjs");
}

main().catch((err) => {
  console.error("FATAL:", err);
  process.exit(1);
});
