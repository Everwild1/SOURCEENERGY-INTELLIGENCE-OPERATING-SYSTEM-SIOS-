function jsonResponse(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export function createWorker(fetchUpstream = fetch) {
  return {
    async fetch(request, env) {
      const url = new URL(request.url);

      if (url.pathname === "/api/universe") {
        if (request.method !== "GET") return jsonResponse({ error: "method_not_allowed" }, 405);
        if (!env.CRUDS_API_URL || !env.CRUDS_API_KEY) return jsonResponse({ error: "gateway_unavailable" }, 503);

        const upstreamUrl = `${env.CRUDS_API_URL.replace(/\/$/, "")}/universe`;
        const upstream = await fetchUpstream(upstreamUrl, {
          method: "GET",
          headers: { Accept: "application/json", apikey: env.CRUDS_API_KEY },
        });

        return new Response(upstream.body, {
          status: upstream.status,
          headers: {
            "Content-Type": upstream.headers.get("content-type") ?? "application/json; charset=utf-8",
            "Cache-Control": upstream.headers.get("cache-control") ?? "no-store",
            "X-Content-Type-Options": "nosniff",
          },
        });
      }

      const assetResponse = await env.ASSETS.fetch(request);
      const acceptsHtml = request.headers.get("accept")?.includes("text/html");

      if (assetResponse.status !== 404 || !acceptsHtml || !["GET", "HEAD"].includes(request.method)) {
        return assetResponse;
      }

      const indexUrl = new URL(request.url);
      indexUrl.pathname = "/index.html";
      indexUrl.search = "";
      return env.ASSETS.fetch(new Request(indexUrl, request));
    },
  };
}

export default createWorker();
