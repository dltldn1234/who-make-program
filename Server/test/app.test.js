import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";
import { createRequestHandler } from "../src/app.js";

const token = "t".repeat(32);
const configuration = {
  clientToken: token,
  requestsPerMinute: 2,
  maxBodyBytes: 1_024
};

async function withServer(run) {
  const calls = [];
  const handler = createRequestHandler(configuration, async input => {
    calls.push(input);
    return {
      statusCode: 200,
      contentType: "application/json",
      body: JSON.stringify({ output: [{ content: [{ type: "output_text", text: "응답" }] }] })
    };
  });
  const server = createServer((request, response) => void handler(request, response));
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  try {
    await run(`http://127.0.0.1:${port}`, calls);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

test("health is public while conversations require the private token", async () => {
  await withServer(async baseURL => {
    const health = await fetch(`${baseURL}/health`);
    assert.equal(health.status, 200);
    assert.equal((await health.json()).status, "ok");

    const unauthorized = await fetch(`${baseURL}/v1/responses`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ input: "안녕" })
    });
    assert.equal(unauthorized.status, 401);
  });
});

test("authenticated input reaches the proxy and preserves its response envelope", async () => {
  await withServer(async (baseURL, calls) => {
    const response = await fetch(`${baseURL}/v1/responses`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-jarvis-client-token": token
      },
      body: JSON.stringify({ input: "오늘 기분 어때?", model: "attacker-model" })
    });

    assert.equal(response.status, 200);
    assert.deepEqual(calls, ["오늘 기분 어때?"]);
    assert.equal((await response.json()).output[0].content[0].text, "응답");
  });
});

test("invalid and excessive input is rejected before proxying", async () => {
  await withServer(async baseURL => {
    const headers = { "content-type": "application/json", "x-jarvis-client-token": token };
    const empty = await fetch(`${baseURL}/v1/responses`, {
      method: "POST",
      headers,
      body: JSON.stringify({ input: " " })
    });
    assert.equal(empty.status, 400);

    const tooLarge = await fetch(`${baseURL}/v1/responses`, {
      method: "POST",
      headers,
      body: JSON.stringify({ input: "x".repeat(2_000) })
    });
    assert.equal(tooLarge.status, 413);
  });
});
