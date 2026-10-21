// Pi status line: replaces the built-in footer with two compact rows.
//
//   ~/Projects/firstmate   main                                  Recall: main
//   claude-opus-5-5 anthropic ◆ low          ctx 12%/200k  ↑1.2k ↓3.4k  $0.42  48 tok/s
//
// Row 1 is where you are: cwd, git branch, session name, and other extensions'
// setStatus() texts on the right. Row 2 is what is answering: model id, provider, and
// thinking level always lead the row, then context usage, token totals, cost, and
// output speed fill the remaining width. Narrow panes shorten the path before the
// branch, shed stats from the least useful end, and move context usage and cost to a
// third row before dropping them. The provider and thinking level give way only when
// the pane is narrower than the model cell itself; the model id is never dropped.
//
// Rows never start with a shell or agent prompt glyph (`$ > % # ❯ › →`) and draw no
// `─` rules or box borders, so Firstmate's composer classifier
// (bin/fm-composer-lib.sh) keeps reading Pi's native editor above it unchanged.
//
// Uses only Pi's public extension API (ctx.ui.setFooter). Output speed is measured
// here; a `tokens-per-second` status from an older standalone extension is hidden
// so it is not shown twice.
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Theme = ExtensionContext["ui"]["theme"];
type Totals = { input: number; output: number; cacheRead: number; cacheWrite: number; cost: number };
type Usage = { input?: number; output?: number; cacheRead?: number; cacheWrite?: number; cost?: { total?: number } | number };
// The slice of a session entry that carries usage (messages, usage, compaction, branch summaries).
type UsageEntry = { type: string; usage?: Usage; message?: { role?: string; usage?: Usage } };

// Statuses this footer draws itself, in the model row, instead of in the status list.
const TOKENS_PER_SECOND_KEY = "tokens-per-second";
const FAST_MODE_KEY = "codex-fast-mode"; // @firstpick/pi-extension-codex-fast-mode: on | off | ultrafast
const TIERS_KEY = "pi-tiers"; // pi-tiers: drawn from its structured route event instead
const HIDDEN_STATUS_KEYS = new Set([TOKENS_PER_SECOND_KEY, FAST_MODE_KEY, TIERS_KEY]);
const TIERS_PROVIDER = "tier";

/** Structured route published by pi-tiers on `pi-tiers:route`. */
interface TierRoute {
	selected: string;
	tier: string;
	auto?: { confidence?: number; unsure: boolean };
	provider: string;
	model: string;
	thinking: string;
	position: number;
	warn: boolean;
}
const SPEED_RENDER_INTERVAL_MS = 250;
const GAP = "  ";
const ICON_DIR = "\uf07b"; // nf-fa-folder
const ICON_BRANCH = "\ue0a0"; // powerline branch
const ICON_MODEL = "◆";

function formatTokens(count: number): string {
	if (count < 1000) return `${count}`;
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function formatCwd(cwd: string): string {
	const home = process.env.HOME || process.env.USERPROFILE;
	if (!home) return cwd;
	if (cwd === home) return "~";
	return cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
}

function sanitize(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function addUsage(totals: Totals, usage: Usage | undefined): void {
	if (!usage) return;
	totals.input += usage.input ?? 0;
	totals.output += usage.output ?? 0;
	totals.cacheRead += usage.cacheRead ?? 0;
	totals.cacheWrite += usage.cacheWrite ?? 0;
	totals.cost += typeof usage.cost === "number" ? usage.cost : (usage.cost?.total ?? 0);
}

function thinkingColor(theme: Theme, level: string): string {
	const token = `thinking${level.charAt(0).toUpperCase()}${level.slice(1)}`;
	try {
		return theme.fg(token as Parameters<Theme["fg"]>[0], level);
	} catch {
		return theme.fg("accent", level);
	}
}

/** `claude-sonnet-5-5` -> `sonnet-5.5`; other ids pass through. */
function shortModel(id: string): string {
	return id.replace(/^claude-/, "").replace(/-(\d+)-(\d+)$/, "-$1.$2");
}

/** Join parts left-aligned and right-aligned on one row of exactly `width` cells. */
function spread(left: string, right: string, width: number): string {
	const room = width - visibleWidth(left) - visibleWidth(right);
	if (right && room >= GAP.length) return left + " ".repeat(room) + right;
	return truncateToWidth(left, width, "…");
}

export default function statusline(pi: ExtensionAPI): void {
	// Output speed of the current or most recent assistant message.
	let speed: { start: number; chars: number; lastRender: number } | undefined;
	let lastRate: number | undefined;
	let requestRender: (() => void) | undefined;
	// Latest pi-tiers route; null when the session is not on a tier.
	let tierRoute: TierRoute | null = null;
	pi.events.on("pi-tiers:route", (data) => {
		tierRoute = (data as TierRoute | null) ?? null;
		requestRender?.();
	});

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui" || !ctx.hasUI) return;
		installFooter(ctx);
	});

	pi.on("turn_start", async () => {
		speed = { start: Date.now(), chars: 0, lastRender: 0 };
	});

	pi.on("message_update", async (event) => {
		if (!speed) return;
		const update = event.assistantMessageEvent;
		if (update.type !== "text_delta" && update.type !== "thinking_delta") return;
		speed.chars += update.delta.length;
		const now = Date.now();
		if (now - speed.lastRender < SPEED_RENDER_INTERVAL_MS) return;
		speed.lastRender = now;
		lastRate = speed.chars / 4 / Math.max(0.001, (now - speed.start) / 1000);
		requestRender?.();
	});

	pi.on("message_end", async (event) => {
		if (!speed || event.message.role !== "assistant") return;
		const seconds = Math.max(0.001, (Date.now() - speed.start) / 1000);
		const reported = (event.message as { usage?: { output?: number } }).usage?.output;
		const tokens = typeof reported === "number" && reported > 0 ? reported : speed.chars / 4;
		if (tokens > 0) lastRate = tokens / seconds;
		requestRender?.();
	});

	pi.on("agent_settled", async () => {
		speed = undefined;
		requestRender?.();
	});

	pi.on("model_select", async () => requestRender?.());
	pi.on("thinking_level_select", async () => requestRender?.());

	function installFooter(ctx: ExtensionContext): void {
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
			let cache: { key: string; totals: Totals } | undefined;

			const usageTotals = (): Totals => {
				const sm = ctx.sessionManager;
				const entries = sm.getEntries();
				const key = `${sm.getSessionId()}:${sm.getLeafId()}:${entries.length}`;
				if (cache?.key === key) return cache.totals;
				const totals: Totals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
				for (const entry of entries as unknown as UsageEntry[]) {
					if (entry.type === "usage") addUsage(totals, entry.usage);
					else if (entry.type === "message" && (entry.message?.role === "assistant" || entry.message?.role === "toolResult")) {
						addUsage(totals, entry.message.usage);
					} else if ((entry.type === "branch_summary" || entry.type === "compaction") && entry.usage) {
						addUsage(totals, entry.usage);
					}
				}
				cache = { key, totals };
				return totals;
			};

			const dim = (text: string) => theme.fg("dim", text);
			const muted = (text: string) => theme.fg("muted", text);

			const locationRow = (width: number): string[] => {
				const cwd = formatCwd(ctx.sessionManager.getCwd());
				const branch = footerData.getGitBranch();
				const name = ctx.sessionManager.getSessionName();
				const build = (path: string) => {
					let row = `${theme.fg("accent", ICON_DIR)} ${theme.fg("text", path)}`;
					if (branch) row += `${GAP}${theme.fg("success", `${ICON_BRANCH} ${branch}`)}`;
					if (name) row += `${GAP}${muted(`• ${sanitize(name)}`)}`;
					return row;
				};
				// Shorten the path before the branch: full, fish-style (~/P/firstmate), last segment.
				const segments = cwd.split("/");
				const fish = segments.map((part, i) => (i === segments.length - 1 ? part : part.startsWith(".") ? part.slice(0, 2) : part.slice(0, 1))).join("/");
				const paths = [cwd, fish, segments[segments.length - 1] || cwd];
				const fitted = (room: number) => {
					const row = paths.map(build).find((candidate) => visibleWidth(candidate) <= room);
					return row ?? truncateToWidth(build(paths[paths.length - 1]), room, dim("…"));
				};

				const statuses = [...footerData.getExtensionStatuses().entries()]
					.filter(([key]) => !HIDDEN_STATUS_KEYS.has(key))
					.sort(([a], [b]) => a.localeCompare(b))
					.map(([, text]) => sanitize(text))
					.filter(Boolean)
					.join(dim(" · "));
				if (!statuses) return [fitted(width)];
				const full = build(cwd);
				if (visibleWidth(full) + GAP.length + visibleWidth(statuses) <= width) return [spread(full, statuses, width)];
				return [fitted(width), truncateToWidth(statuses, width, dim("…"))];
			};

			const modelRows = (width: number): string[] => {
				const model = ctx.model;
				const level = pi.getThinkingLevel() || "off";
				const id = model?.id ?? "no model";
				const name = theme.bold(theme.fg("accent", id));
				const provider = model ? muted(model.provider) : "";
				const thinking = model?.reasoning === false
					? dim(`${ICON_MODEL} no thinking`)
					: `${theme.fg("dim", ICON_MODEL)} ${thinkingColor(theme, level)}`;
				const fastMode = sanitize(footerData.getExtensionStatuses().get(FAST_MODE_KEY) ?? "");
				const fast = fastMode === "on" ? theme.fg("warning", "⚡fast") : fastMode === "ultrafast" ? theme.fg("warning", "⚡ultrafast") : "";
				// Widest first; the model id itself is never dropped.
				let variants = [
					[name, provider, thinking, fast].filter(Boolean).join(" "),
					[name, thinking, fast].filter(Boolean).join(" "),
					[name, thinking].join(" "),
					name,
				];
				if (model?.provider === TIERS_PROVIDER) {
					// pi-tiers: `auto → deep ↓2 → opus-5.5 xhigh · anthropic-2`. Drop order on narrow panes:
					// account, then the auto step, then the effort; the answering model always stays.
					const route = tierRoute && tierRoute.selected === model.id ? tierRoute : undefined;
					const arrow = dim(" → ");
					const autoStep = route?.auto ? muted(route.auto.unsure ? "auto?" : "auto") + arrow : "";
					const tierName = theme.fg("text", route?.tier ?? model.id);
					const drop = route && route.position > 1 ? theme.fg("warning", ` ↓${route.position}`) : "";
					const answering = route ? theme.bold(theme.fg(route.warn ? "warning" : "accent", shortModel(route.model))) : dim("…");
					const effort = route ? ` ${thinkingColor(theme, route.thinking)}` : "";
					const account = route ? `${dim(" · ")}${muted(route.provider)}` : "";
					variants = [
						`${autoStep}${tierName}${drop}${arrow}${answering}${effort}${account}`,
						`${autoStep}${tierName}${drop}${arrow}${answering}${effort}`,
						`${tierName}${drop}${arrow}${answering}${effort}`,
						`${answering}${effort}`,
						answering,
					];
				}
				const head = variants.find((variant) => visibleWidth(variant) <= width) ?? truncateToWidth(name, width, "…");

				const totals = usageTotals();
				const usage = ctx.getContextUsage();
				// Shown in this order; a higher priority number is dropped first when space runs out.
				const stats: Array<{ text: string; priority: number }> = [];
				if (usage) {
					const window = formatTokens(usage.contextWindow);
					const percent = usage.percent;
					const label = percent === null ? `ctx ?/${window}` : `ctx ${percent.toFixed(percent < 10 ? 1 : 0)}%/${window}`;
					const color = percent !== null && percent > 90 ? "error" : percent !== null && percent > 70 ? "warning" : "muted";
					stats.push({ text: theme.fg(color, label), priority: 0 });
				}
				if (totals.input || totals.output) {
					stats.push({ text: dim(`↑${formatTokens(totals.input)} ↓${formatTokens(totals.output)}`), priority: 3 });
				}
				const promptTokens = totals.input + totals.cacheRead + totals.cacheWrite;
				if (totals.cacheRead && promptTokens) {
					stats.push({ text: dim(`cache ${Math.round((totals.cacheRead / promptTokens) * 100)}%`), priority: 4 });
				}
				const subscription = model ? ctx.modelRegistry.isUsingOAuth(model) : false;
				if (totals.cost || subscription) {
					stats.push({ text: muted(`$${totals.cost.toFixed(2)}${subscription ? " sub" : ""}`), priority: 1 });
				}
				if (lastRate !== undefined) {
					const rate = lastRate >= 100 ? lastRate.toFixed(0) : lastRate.toFixed(1);
					stats.push({ text: (speed ? theme.fg("accent", rate) : muted(rate)) + dim(" tok/s"), priority: 2 });
				}

				// Drop the lowest-priority stats until they fit in `room` cells.
				const fit = (room: number) => {
					const shown = [...stats];
					const text = () => shown.map((stat) => stat.text).join(GAP);
					while (shown.length && visibleWidth(text()) > room) {
						let worst = 0;
						for (let i = 1; i < shown.length; i++) if (shown[i].priority > shown[worst].priority) worst = i;
						shown.splice(worst, 1);
					}
					return { text: text(), count: shown.length };
				};
				const beside = fit(width - visibleWidth(head) - GAP.length);
				// Context usage and cost (priority 0-1) are worth a row of their own in a narrow pane.
				const essential = stats.filter((stat) => stat.priority <= 1).length;
				if (beside.count >= essential) return [spread(head, beside.text, width)];
				return [head, fit(width).text].filter(Boolean);
			};

			return {
				dispose() {
					unsubscribe();
					requestRender = undefined;
				},
				invalidate() {
					cache = undefined;
				},
				render(width: number): string[] {
					try {
						// One cell of margin each side lines the footer up with the transcript text.
						const margin = width >= 24 ? 1 : 0;
						const inner = width - margin * 2;
						const pad = " ".repeat(margin);
						return [...locationRow(inner), ...modelRows(inner)].map((row) => pad + row);
					} catch {
						// A stale ctx during session replacement must not take the TUI down.
						return [];
					}
				},
			};
		});
	}
}
