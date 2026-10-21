// Run only after Pi has exhausted its normal retries. Keep the selected Vertex
// model for subsequent turns until the user explicitly selects another model.
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function anthropicRateLimitFallback(pi: ExtensionAPI): void {
  // The Vertex extension and its dependencies are deliberately macOS-only.
  if (process.platform !== "darwin") return;

  let lastAssistant: AssistantMessage | undefined;
  pi.on("agent_start", () => { lastAssistant = undefined; });
  pi.on("message_end", event => {
    if (event.message.role === "assistant") lastAssistant = event.message;
  });
  pi.on("agent_before_settle", async (event, ctx) => {
    const failed = lastAssistant;
    if (event.outcome !== "error" || failed?.stopReason !== "error" ||
        failed.provider !== "anthropic" || ctx.model?.provider !== "anthropic" ||
        ctx.model.id !== failed.model || ctx.signal?.aborted ||
        !/\b429\b|\brate[_ -]?limit(?:ed|_error)?\b|\btoo many requests\b/i.test(failed.errorMessage ?? "")) return;

    const fallback = ctx.modelRegistry.find("vertex-claude", failed.model);
    if (!fallback || !(await pi.setModel(fallback))) return;

    // A boundary message both records the switch visibly and gives continuation
    // runnable context without replaying the user's request or completed tools.
    return {
      entries: [{
        type: "custom_message" as const,
        customType: "anthropic-rate-limit-fallback",
        content: `Anthropic rate limited. Switched to vertex-claude/${fallback.id}; continuing the interrupted turn.`,
        display: true,
      }],
      continue: true,
    };
  });
}
