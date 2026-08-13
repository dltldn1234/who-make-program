import { safetyIdentifier } from "./auth.js";

const INSTRUCTIONS = [
  "당신은 한 사용자를 위한 개인 비서 JARVIS입니다.",
  "한국어로 자연스럽고 간결하게 답하세요.",
  "실제로 수행하지 않은 기기 동작을 수행했다고 주장하지 마세요.",
  "사용자의 앱이 로컬 명령 실행과 승인을 별도로 담당합니다."
].join(" ");

export function createOpenAIProxy(configuration, fetchImplementation = fetch) {
  return async function proxy(input) {
    const upstream = await fetchImplementation(configuration.openAIEndpoint, {
      method: "POST",
      headers: {
        authorization: `Bearer ${configuration.openAIKey}`,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        model: configuration.model,
        instructions: INSTRUCTIONS,
        input,
        store: false,
        safety_identifier: safetyIdentifier(configuration.clientToken)
      }),
      signal: AbortSignal.timeout(45_000)
    });

    const body = await upstream.text();
    return {
      statusCode: upstream.status,
      contentType: upstream.headers.get("content-type") ?? "application/json",
      body
    };
  };
}
