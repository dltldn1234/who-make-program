import assert from "node:assert/strict";
import test from "node:test";
import { createOpenAIProxy } from "../src/openai.js";

test("proxy owns model, instructions, credential, and safety identity", async () => {
  let captured;
  const configuration = {
    openAIEndpoint: "https://api.openai.com/v1/responses",
    openAIKey: "upstream-secret",
    clientToken: "c".repeat(32),
    model: "test-model"
  };
  const proxy = createOpenAIProxy(configuration, async (url, options) => {
    captured = { url, options };
    return new Response('{"output":[]}', {
      status: 200,
      headers: { "content-type": "application/json" }
    });
  });

  const result = await proxy("안녕");
  const body = JSON.parse(captured.options.body);
  assert.equal(captured.url, configuration.openAIEndpoint);
  assert.equal(captured.options.headers.authorization, "Bearer upstream-secret");
  assert.equal(body.model, "test-model");
  assert.equal(body.input, "안녕");
  assert.equal(body.store, false);
  assert.match(body.safety_identifier, /^jarvis_[a-f0-9]{24}$/);
  assert.match(body.instructions, /개인 비서 JARVIS/);
  assert.equal(result.statusCode, 200);
});
