const DEFAULT_PORT = 8787;
const DEFAULT_CODEX_BINARY = "/Users/isiu/.local/bin/codex";

export function loadConfiguration(environment = process.env) {
  const port = parseInteger(environment.PORT, DEFAULT_PORT, 1, 65_535, "PORT");
  const requestsPerMinute = parseInteger(
    environment.JARVIS_REQUESTS_PER_MINUTE,
    20,
    1,
    600,
    "JARVIS_REQUESTS_PER_MINUTE"
  );
  const clientToken = required(environment.JARVIS_CLIENT_TOKEN, "JARVIS_CLIENT_TOKEN");

  if (clientToken.length < 32) {
    throw new Error("JARVIS_CLIENT_TOKEN must contain at least 32 characters");
  }

  return Object.freeze({
    host: environment.HOST?.trim() || "127.0.0.1",
    port,
    clientToken,
    requestsPerMinute,
    maxBodyBytes: 32 * 1024,
    codexBinary: environment.CODEX_BINARY?.trim() || DEFAULT_CODEX_BINARY,
    codexHome: environment.CODEX_HOME?.trim() || `${environment.HOME || "/Users/isiu"}/.codex`,
    codexWorkingDirectory: environment.CODEX_WORKING_DIRECTORY?.trim() || process.cwd(),
    logCodexErrors: environment.JARVIS_LOG_CODEX_ERRORS === "1"
  });
}

function required(value, name) {
  const normalized = value?.trim();
  if (!normalized) throw new Error(`${name} is required`);
  return normalized;
}

function parseInteger(rawValue, fallback, minimum, maximum, name) {
  if (rawValue === undefined || rawValue === "") return fallback;
  const value = Number(rawValue);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}`);
  }
  return value;
}
