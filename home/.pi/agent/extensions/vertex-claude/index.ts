/**
 * Claude on Google Vertex AI for Pi.
 *
 * Reuses Pi's built-in Anthropic Messages implementation and swaps the transport:
 * a custom fetch rewrites each request into Vertex `:streamRawPredict` form,
 * authenticates with ADC / the service-account file, and sends the same
 * `claude-cli` User-Agent OMP uses (dotfiles/home/.omp/agent/models.yml).
 *
 * Config (first match wins): process env, then ~/.omp/agent/.env.
 *   GOOGLE_APPLICATION_CREDENTIALS  service-account JSON (optional; ADC otherwise)
 *   GOOGLE_CLOUD_PROJECT            project id
 *   VERTEX_LOCATION                 region, "global" by default
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
	type Api,
	anthropicMessagesApi,
	getModels,
	type Model,
	type SimpleStreamOptions,
	type TranscriptContext,
} from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { GoogleAuth } from "google-auth-library";

const PROVIDER = "vertex-claude";
const USER_AGENT = "claude-cli/2.1.280 (external, cli)";
const VERTEX_ANTHROPIC_VERSION = "vertex-2023-10-16";

/** Pi Anthropic catalog id -> Vertex publisher model id. Mirrors the OMP models.yml list. */
const VERTEX_IDS: Record<string, string> = {
	"claude-fable-5": "claude-fable-5@default",
	"claude-haiku-4-5": "claude-haiku-4-5@20251001",
	"claude-haiku-5-5": "claude-haiku-5-5@default",
	"claude-opus-4-5": "claude-opus-4-5@20251101",
	"claude-opus-4-6": "claude-opus-4-6@default",
	"claude-opus-4-7": "claude-opus-4-7@default",
	"claude-opus-4-8": "claude-opus-4-8@default",
	"claude-opus-5": "claude-opus-5@default",
	"claude-opus-5-5": "claude-opus-5-5@default",
	"claude-sonnet-4-5": "claude-sonnet-4-5@20250929",
	"claude-sonnet-4-6": "claude-sonnet-4-6@default",
	"claude-sonnet-5": "claude-sonnet-5@default",
	"claude-sonnet-5-5": "claude-sonnet-5-5@default",
};

/**
 * Betas Vertex rejects (the org policy blocks structured outputs; thinking-binding
 * controls and server-side fallback are first-party only). Everything else passes
 * through in the body as `anthropic_beta`, which is how Vertex takes betas.
 */
const DROPPED_BETA_PREFIXES = ["thinking-binding-controls", "server-side-fallback", "structured-outputs"];

function readEnvFile(path: string): Record<string, string> {
	try {
		const out: Record<string, string> = {};
		for (const line of readFileSync(path, "utf8").split("\n")) {
			const m = /^\s*(?:export\s+)?([A-Z0-9_]+)\s*=\s*(.*?)\s*$/.exec(line);
			if (m) out[m[1]] = m[2].replace(/^(['"])(.*)\1$/, "$2");
		}
		return out;
	} catch {
		return {};
	}
}

const fileEnv = readEnvFile(join(homedir(), ".omp", "agent", ".env"));
const env = (name: string): string | undefined => process.env[name] || fileEnv[name] || undefined;

const project = env("GOOGLE_CLOUD_PROJECT") ?? env("GCLOUD_PROJECT");
const location = env("VERTEX_LOCATION") ?? env("GOOGLE_CLOUD_LOCATION") ?? "global";
const keyFile = env("GOOGLE_APPLICATION_CREDENTIALS");
const host = location === "global" ? "aiplatform.googleapis.com" : `${location}-aiplatform.googleapis.com`;

const auth = new GoogleAuth({
	scopes: ["https://www.googleapis.com/auth/cloud-platform"],
	...(keyFile ? { keyFile } : {}),
});

function vertexFetch(vertexId: string): typeof fetch {
	const endpoint = `https://${host}/v1/projects/${project}/locations/${location}/publishers/anthropic/models/${vertexId}`;
	return async (input, init) => {
		const request = new Request(input, init);
		const suffix = new URL(request.url).pathname.endsWith("/count_tokens") ? "count-tokens:rawPredict" : ":streamRawPredict";
		const url = suffix.startsWith(":") ? endpoint + suffix : endpoint.replace(/models\/[^/]+$/, `models/${suffix}`);

		const body = JSON.parse(await request.text()) as Record<string, unknown>;
		if (suffix.startsWith(":")) delete body.model;
		body.anthropic_version = VERTEX_ANTHROPIC_VERSION;

		const betas = (request.headers.get("anthropic-beta") ?? "")
			.split(",")
			.map((b) => b.trim())
			.filter((b) => b && !DROPPED_BETA_PREFIXES.some((p) => b.startsWith(p)));
		if (betas.length > 0) body.anthropic_beta = betas;
		if (body.thinking && typeof body.thinking === "object") delete (body.thinking as Record<string, unknown>).block_binding;
		delete body.fallbacks;
		if (Array.isArray(body.tools)) for (const tool of body.tools as Record<string, unknown>[]) delete tool.strict;

		const token = await auth.getAccessToken();
		if (!token) throw new Error("vertex-claude: no Google access token (check GOOGLE_APPLICATION_CREDENTIALS / ADC)");

		const headers = new Headers(request.headers);
		for (const h of ["x-api-key", "anthropic-beta", "anthropic-version", "anthropic-dangerous-direct-browser-access", "content-length"]) {
			headers.delete(h);
		}
		for (const h of [...headers.keys()]) if (h.startsWith("x-stainless")) headers.delete(h);
		headers.set("authorization", `Bearer ${token}`);
		headers.set("user-agent", USER_AGENT);
		headers.set("content-type", "application/json");

		return fetch(url, { method: "POST", headers, body: JSON.stringify(body), signal: request.signal });
	};
}

function streamVertexClaude(model: Model<Api>, context: TranscriptContext, options?: SimpleStreamOptions) {
	const vertexId = VERTEX_IDS[model.id] ?? `${model.id}@default`;
	return anthropicMessagesApi().streamSimple(
		{ ...(model as Model<"anthropic-messages">), api: "anthropic-messages", baseUrl: "https://vertex.invalid" },
		context,
		{ ...options, apiKey: "vertex-adc", fetch: vertexFetch(vertexId) },
	);
}

export default function (pi: ExtensionAPI) {
	if (!project) return; // No Vertex project configured: stay out of /model.

	const models = getModels("anthropic")
		.filter((m) => m.id in VERTEX_IDS)
		.map((m) => ({
			id: m.id,
			name: `${m.name} (Vertex)`,
			reasoning: m.reasoning,
			thinkingLevelMap: m.thinkingLevelMap,
			input: m.input,
			cost: m.cost,
			promptCache: m.promptCache,
			contextWindow: m.contextWindow,
			maxTokens: m.maxTokens,
			compat: {
				...m.compat,
				// Vertex org policy disallows structured outputs; binding controls need a first-party beta.
				supportsStrictTools: false,
				supportsMidConvoEffort: false,
				supportsMidConvoToolChanges: false,
				allowedFallbackModels: undefined,
			},
		}));

	pi.registerProvider(PROVIDER, {
		name: "Vertex AI (Claude)",
		baseUrl: "https://vertex.invalid",
		apiKey: "vertex-adc",
		api: "vertex-claude-api",
		models,
		streamSimple: streamVertexClaude,
	});
}
