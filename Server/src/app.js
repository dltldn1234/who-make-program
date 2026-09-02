import { isAuthorized } from "./auth.js";
import { SlidingWindowRateLimiter } from "./rate-limit.js";

export function createRequestHandler(configuration, proxy) {
  const limiter = new SlidingWindowRateLimiter(configuration.requestsPerMinute);

  return async function handle(request, response) {
    applySecurityHeaders(response);

    if (request.method === "GET" && request.url === "/health") {
      return sendJSON(response, 200, { status: "ok", service: "jarvis-personal-server" });
    }

    if (request.method !== "POST" || request.url !== "/v1/responses") {
      return sendJSON(response, 404, { error: { message: "Route not found" } });
    }

    const token = request.headers["x-jarvis-client-token"];
    if (!isAuthorized(token, configuration.clientToken)) {
      return sendJSON(response, 401, { error: { message: "Unauthorized client" } });
    }

    const clientAddress = request.socket.remoteAddress ?? "unknown";
    const rate = limiter.consume(`${clientAddress}:${token}`);
    if (!rate.allowed) {
      response.setHeader("retry-after", String(rate.retryAfterSeconds));
      return sendJSON(response, 429, { error: { message: "Request limit exceeded" } });
    }
    response.setHeader("x-ratelimit-remaining", String(rate.remaining));

    try {
      const payload = await readJSON(request, configuration.maxBodyBytes);
      const input = typeof payload.input === "string" ? payload.input.trim() : "";
      if (!input || input.length > 12_000) {
        return sendJSON(response, 400, { error: { message: "input must contain 1 to 12000 characters" } });
      }

      const upstream = await proxy(input);
      response.writeHead(upstream.statusCode, { "content-type": upstream.contentType });
      response.end(upstream.body);
    } catch (error) {
      if (error?.code === "BODY_TOO_LARGE") {
        return sendJSON(response, 413, { error: { message: "Request body is too large" } });
      }
      if (error instanceof SyntaxError) {
        return sendJSON(response, 400, { error: { message: "Malformed JSON body" } });
      }
      if (error?.code === "usageLimitExceeded" || error?.code === "sessionBudgetExceeded") {
        return sendJSON(response, 429, {
          error: { message: "Codex 사용량 한도에 도달했습니다. Codex 설정의 Usage/Credits를 확인해 주세요." }
        });
      }
      console.error("jarvis_request_failed", error instanceof Error ? error.message : error);
      return sendJSON(response, 502, { error: { message: "AI upstream unavailable" } });
    }
  };
}

function readJSON(request, maximumBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let received = 0;
    let exceeded = false;
    request.on("data", chunk => {
      received += chunk.length;
      if (received > maximumBytes) {
        exceeded = true;
        return;
      }
      chunks.push(chunk);
    });
    request.on("end", () => {
      if (exceeded) {
        const error = new Error("body too large");
        error.code = "BODY_TOO_LARGE";
        reject(error);
        return;
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch (error) {
        reject(error);
      }
    });
    request.on("error", reject);
  });
}

function applySecurityHeaders(response) {
  response.setHeader("cache-control", "no-store");
  response.setHeader("content-security-policy", "default-src 'none'");
  response.setHeader("x-content-type-options", "nosniff");
  response.setHeader("referrer-policy", "no-referrer");
}

function sendJSON(response, statusCode, value) {
  response.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(value));
}
