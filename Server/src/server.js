import { createServer } from "node:http";
import { createRequestHandler } from "./app.js";
import { loadConfiguration } from "./config.js";
import { createCodexProxy } from "./codex.js";

const configuration = loadConfiguration();
const handler = createRequestHandler(configuration, createCodexProxy(configuration));
const server = createServer((request, response) => {
  void handler(request, response);
});

server.requestTimeout = 50_000;
server.headersTimeout = 10_000;
server.listen(configuration.port, configuration.host, () => {
  console.log(`jarvis_server_ready http://${configuration.host}:${configuration.port}`);
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
