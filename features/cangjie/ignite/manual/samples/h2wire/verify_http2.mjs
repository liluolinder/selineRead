import assert from "node:assert/strict";
import http2 from "node:http2";
import { performance } from "node:perf_hooks";

const BASE_URL = "https://127.0.0.1:18444";

function fetchHttp2(path) {
  return new Promise((resolve, reject) => {
    const session = http2.connect(BASE_URL, {
      rejectUnauthorized: false,
      ALPNProtocols: ["h2"],
    });

    let resolved = false;
    session.on("error", (error) => {
      if (!resolved) {
        reject(error);
      }
    });

    const req = session.request({
      ":method": "GET",
      ":path": path,
    });

    let headers = {};
    const chunks = [];
    let dataEvents = 0;
    let firstDataAt = null;
    let lastDataAt = null;

    req.on("response", (responseHeaders) => {
      headers = responseHeaders;
    });

    req.on("data", (chunk) => {
      const now = performance.now();
      if (firstDataAt === null) {
        firstDataAt = now;
      }
      lastDataAt = now;
      dataEvents += 1;
      chunks.push(Buffer.from(chunk));
    });

    req.on("end", () => {
      const body = Buffer.concat(chunks);
      const alpnProtocol = session.socket?.alpnProtocol ?? "";
      resolved = true;
      session.close();
      resolve({
        alpnProtocol,
        headers,
        body,
        dataEvents,
        dataSpanMs:
          firstDataAt === null || lastDataAt === null ? 0 : lastDataAt - firstDataAt,
      });
    });

    req.on("error", (error) => {
      if (!resolved) {
        reject(error);
      }
    });

    req.end();
  });
}

const streamResp = await fetchHttp2("/stream");
assert.equal(streamResp.alpnProtocol, "h2");
assert.equal(streamResp.headers[":status"], 200);
assert.equal(streamResp.headers["transfer-encoding"], undefined);
assert.equal(streamResp.headers["x-h2-wire-mode"], "writer");
assert.equal(streamResp.body.toString("utf8"), "chunk-1\nchunk-2\nchunk-3\n");
assert.ok(
  streamResp.dataEvents >= 2,
  `expected at least 2 data events for /stream, got ${streamResp.dataEvents}`,
);
assert.ok(
  streamResp.dataSpanMs >= 60,
  `expected staggered stream delivery for /stream, got span ${streamResp.dataSpanMs}ms`,
);

const fileResp = await fetchHttp2("/file");
assert.equal(fileResp.alpnProtocol, "h2");
assert.equal(fileResp.headers[":status"], 200);
assert.equal(fileResp.headers["transfer-encoding"], undefined);
assert.equal(fileResp.headers["x-h2-wire-mode"], "sendFile");

const expectedSize = Number(fileResp.headers["x-h2-wire-size"] ?? "0");
assert.ok(expectedSize > 65536, `expected large file payload, got ${expectedSize}`);
assert.equal(Number(fileResp.headers["content-length"]), expectedSize);
assert.equal(fileResp.body.length, expectedSize);
assert.match(fileResp.body.toString("utf8", 0, 32), /^ignite-h2-wire-file-block-/);

console.log(
  JSON.stringify(
    {
      ok: true,
      stream: {
        alpn: streamResp.alpnProtocol,
        dataEvents: streamResp.dataEvents,
        dataSpanMs: Math.round(streamResp.dataSpanMs),
      },
      file: {
        alpn: fileResp.alpnProtocol,
        bytes: fileResp.body.length,
      },
    },
    null,
    2,
  ),
);
