import assert from "node:assert/strict";
import { access } from "node:fs/promises";
import test from "node:test";
import worker, { createWorker } from "../worker/index.js";

test("proxies the live universe through server-side gateway credentials", async () => {
  let upstreamRequest;
  const proxyWorker = createWorker(async (input, init) => {
    upstreamRequest = new Request(input, init);
    return new Response(JSON.stringify({ contractVersion: "cruds-e09.v1" }), {
      headers: { "content-type": "application/json", "cache-control": "public, max-age=60" },
    });
  });

  const response = await proxyWorker.fetch(new Request("https://example.test/api/universe"), {
    CRUDS_API_URL: "https://gateway.example/functions/v1/cruds-public-universe/",
    CRUDS_API_KEY: "publishable-test-key",
    ASSETS: { fetch: async () => new Response("unused", { status: 500 }) },
  });

  assert.equal(response.status, 200);
  assert.equal(upstreamRequest.url, "https://gateway.example/functions/v1/cruds-public-universe/universe");
  assert.equal(upstreamRequest.headers.get("apikey"), "publishable-test-key");
  assert.equal(response.headers.get("cache-control"), "public, max-age=60");
});

test("fails closed when the live gateway is not configured", async () => {
  const response = await worker.fetch(new Request("https://example.test/api/universe"), {
    ASSETS: { fetch: async () => new Response("unused", { status: 500 }) },
  });

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "gateway_unavailable" });
});

test("serves existing static assets without a fallback", async () => {
  const calls = [];
  const response = await worker.fetch(new Request("https://example.test/assets/app.js"), {
    ASSETS: {
      fetch: async (request) => {
        calls.push(new URL(request.url).pathname);
        return new Response("asset", { status: 200 });
      },
    },
  });

  assert.equal(response.status, 200);
  assert.deepEqual(calls, ["/assets/app.js"]);
});

test("falls back to index.html for an unknown app route", async () => {
  const calls = [];
  const response = await worker.fetch(
    new Request("https://example.test/flow/step-two?source=share", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async (request) => {
          const url = new URL(request.url);
          calls.push(url.pathname + url.search);
          return new Response(url.pathname === "/index.html" ? "app" : "missing", {
            status: url.pathname === "/index.html" ? 200 : 404,
          });
        },
      },
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(calls, ["/flow/step-two?source=share", "/index.html"]);
});

test("does not turn missing API or write requests into the app shell", async () => {
  for (const request of [
    new Request("https://example.test/api/missing", { headers: { accept: "application/json" } }),
    new Request("https://example.test/flow", { method: "POST", headers: { accept: "text/html" } }),
  ]) {
    let calls = 0;
    const response = await worker.fetch(request, {
      ASSETS: {
        fetch: async () => {
          calls += 1;
          return new Response("missing", { status: 404 });
        },
      },
    });

    assert.equal(response.status, 404);
    assert.equal(calls, 1);
  }
});

test("emits the files required by Sites packaging", async () => {
  await access(new URL("../dist/client/index.html", import.meta.url));
  await access(new URL("../dist/server/index.js", import.meta.url));
  await access(new URL("../dist/.openai/hosting.json", import.meta.url));
});
