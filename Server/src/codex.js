import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const JARVIS_INSTRUCTIONS = [
  "당신은 한 명의 사용자를 위한 개인 비서 JARVIS입니다.",
  "한국어로 자연스럽고 간결하게 답하세요.",
  "실제로 수행하지 않은 기기 동작을 수행했다고 주장하지 마세요.",
  "이 연결은 질문과 답변 전용이며, 쉘 명령을 실행하거나 파일을 변경하지 마세요."
].join(" ");

export function createCodexProxy(configuration, options = {}) {
  const client = new CodexAppServerClient(configuration, options);
  return input => client.answer(input);
}

export class CodexAppServerClient {
  #configuration;
  #spawn = null;
  #readline = null;
  #pending = new Map();
  #nextRequestId = 0;
  #ready = null;
  #threadId = null;
  #process = null;
  #turn = Promise.resolve();

  constructor(configuration, options = {}) {
    this.#configuration = configuration;
    this.#spawn = options.spawn ?? spawn;
  }

  answer(input) {
    const run = this.#turn.then(() => this.#answer(input));
    this.#turn = run.catch(() => undefined);
    return run;
  }

  async #answer(input) {
    await this.#ensureReady();
    const turn = await this.#request("turn/start", {
      threadId: this.#threadId,
      approvalPolicy: "never",
      input: [{ type: "text", text: input }]
    });

    const turnId = turn?.turn?.id;
    if (!turnId) {
      throw new Error("Codex did not return a turn id");
    }

    const text = await this.#waitForTurn(turnId);
    if (!text.trim()) {
      throw new Error("Codex returned an empty response");
    }

    return {
      statusCode: 200,
      contentType: "application/json; charset=utf-8",
      body: JSON.stringify({
        output: [{ content: [{ type: "output_text", text }] }]
      })
    };
  }

  async #ensureReady() {
    if (!this.#ready) {
      this.#ready = this.#start().catch(error => {
        this.#ready = null;
        this.#shutdown();
        throw error;
      });
    }
    return this.#ready;
  }

  async #start() {
    const process = this.#spawn(this.#configuration.codexBinary, ["app-server", "--stdio"], {
      cwd: this.#configuration.codexWorkingDirectory,
      env: {
        ...processEnv(),
        CODEX_HOME: this.#configuration.codexHome
      },
      stdio: ["pipe", "pipe", "pipe"]
    });
    this.#process = process;
    this.#readline = createInterface({ input: process.stdout });
    this.#readline.on("line", line => this.#receive(line));
    process.stderr.on("data", chunk => {
      if (this.#configuration.logCodexErrors) {
        console.error("codex_app_server", String(chunk).trim());
      }
    });
    process.once("error", error => this.#failPending(error));
    process.once("exit", (code, signal) => {
      const error = new Error(`Codex app-server exited (${code ?? signal ?? "unknown"})`);
      this.#failPending(error);
      this.#ready = null;
      this.#threadId = null;
    });

    await this.#request("initialize", {
      clientInfo: { name: "jarvis-personal-server", version: "1.0.0" },
      capabilities: { experimentalApi: true }
    });
    this.#notify("initialized", {});
    const thread = await this.#request("thread/start", {
      cwd: this.#configuration.codexWorkingDirectory,
      ephemeral: true,
      approvalPolicy: "never",
      sandbox: "read-only",
      developerInstructions: JARVIS_INSTRUCTIONS
    });
    this.#threadId = thread?.thread?.id;
    if (!this.#threadId) {
      throw new Error("Codex did not return a thread id");
    }
  }

  #waitForTurn(turnId) {
    return new Promise((resolve, reject) => {
      let responseText = "";
      const onMessage = message => {
        if (message.method === "item/agentMessage/delta" && message.params?.turnId === turnId) {
          responseText += message.params.delta ?? "";
        }
        if (message.method !== "turn/completed" || message.params?.turn?.id !== turnId) return;
        this.#pending.delete(`turn:${turnId}`);
        const error = message.params.turn?.error;
        if (error) {
          reject(new CodexServiceError(error.message ?? "Codex turn failed", error.codexErrorInfo));
        } else {
          resolve(responseText);
        }
      };
      this.#pending.set(`turn:${turnId}`, { onMessage, reject });
    });
  }

  #request(method, params) {
    const id = ++this.#nextRequestId;
    return new Promise((resolve, reject) => {
      this.#pending.set(id, { resolve, reject });
      this.#write({ jsonrpc: "2.0", id, method, params });
    });
  }

  #notify(method, params) {
    this.#write({ jsonrpc: "2.0", method, params });
  }

  #write(message) {
    if (!this.#process?.stdin.writable) {
      throw new Error("Codex app-server stdin is unavailable");
    }
    this.#process.stdin.write(`${JSON.stringify(message)}\n`);
  }

  #receive(line) {
    if (!line.trim()) return;
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      return;
    }
    if (message.id !== undefined && this.#pending.has(message.id)) {
      const pending = this.#pending.get(message.id);
      this.#pending.delete(message.id);
      if (message.error) {
        pending.reject(new CodexServiceError(message.error.message ?? "Codex request failed"));
      } else {
        pending.resolve(message.result);
      }
      return;
    }
    for (const pending of this.#pending.values()) {
      pending.onMessage?.(message);
    }
  }

  #failPending(error) {
    for (const pending of this.#pending.values()) pending.reject(error);
    this.#pending.clear();
  }

  #shutdown() {
    this.#readline?.close();
    this.#process?.kill();
    this.#readline = null;
    this.#process = null;
    this.#threadId = null;
  }
}

export class CodexServiceError extends Error {
  constructor(message, code = null) {
    super(message);
    this.name = "CodexServiceError";
    this.code = code;
  }
}

function processEnv() {
  return typeof process === "undefined" ? {} : process.env;
}
