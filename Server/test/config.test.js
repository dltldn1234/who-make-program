import assert from "node:assert/strict";
import test from "node:test";
import { isAuthorized, safetyIdentifier } from "../src/auth.js";
import { loadConfiguration } from "../src/config.js";

const validEnvironment = {
  JARVIS_CLIENT_TOKEN: "a".repeat(32)
};

test("configuration uses private local defaults", () => {
  const configuration = loadConfiguration(validEnvironment);
  assert.equal(configuration.host, "127.0.0.1");
  assert.equal(configuration.port, 8787);
  assert.equal(configuration.codexBinary, "/Users/isiu/.local/bin/codex");
  assert.match(configuration.codexHome, /\.codex$/);
});

test("configuration rejects missing secrets and weak client tokens", () => {
  assert.throws(() => loadConfiguration({}), /JARVIS_CLIENT_TOKEN/);
  assert.throws(
    () => loadConfiguration({ ...validEnvironment, JARVIS_CLIENT_TOKEN: "short" }),
    /at least 32/
  );
});

test("client authentication requires an exact constant-time-compatible token", () => {
  assert.equal(isAuthorized("a".repeat(32), "a".repeat(32)), true);
  assert.equal(isAuthorized("b".repeat(32), "a".repeat(32)), false);
  assert.equal(isAuthorized("short", "a".repeat(32)), false);
});

test("safety identifier is stable and does not expose the client token", () => {
  const token = "private-client-token".repeat(2);
  assert.equal(safetyIdentifier(token), safetyIdentifier(token));
  assert.equal(safetyIdentifier(token).includes(token), false);
});
