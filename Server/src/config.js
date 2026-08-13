const DEFAULT_PORT = 8787;
const DEFAULT_MODEL = "gpt-5.6-terra";

export function loadConfiguration(environment = process.env) {
  const port = parseInteger(environment.PORT, DEFAULT_PORT, 1, 65_535, "PORT");
  const requestsPerMinute = parseInteger(
    environment.JARVIS_REQUESTS_PER_MINUTE,
    20,
    1,
    600,
    "JARVIS_REQUESTS_PER_MINUTE"
  );
  const openAIKey = required(environment.OPENAI_API_KEY, "OPENAI_API_KEY");
  const clientToken = required(environment.JARVIS_CLIENT_TOKEN, "JARVIS_CLIENT_TOKEN");

  if (clientToken.length < 32) {
    throw new Error("JARVIS_CLIENT_TOKEN must contain at least 32 characters");
  }

  return Object.freeze({
    host: environment.HOST?.trim() || "127.0.0.1",
    port,
    model: environment.OPENAI_MODEL?.trim() || DEFAULT_MODEL,
    openAIKey,
    clientToken,
    requestsPerMinute,
    maxBodyBytes: 32 * 1024,
    openAIEndpoint: "https://api.openai.com/v1/responses"
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
