# Shared Pi configuration

`home.nix` links `settings.json`, `tiers.json`, the shared extensions (`fm-readable-ui.ts`, `statusline.ts`, `fm-optchat/`), and the OptChat preparation directory individually into `~/.pi/agent`. On macOS it also links `vertex-claude/` and `anthropic-rate-limit-fallback.ts`. This leaves unrelated extensions, local providers, and credentials alone. Restart Pi after landing the links. Do not replace the whole agent directory.

The committed settings are the current Mac configuration, not new defaults. They contain no credentials. Keep `auth.json`, `models.json`, `models-store.json`, `mcp-auth.json`, and `.env` local. Pi can save through this editable out-of-store link; review subsequent changes before committing them.

`pi-zentui` is no longer installed by `settings.json`, so no session loads its editor, footer, or message styles after a switch. Its installed copy under `~/.pi/agent/npm/node_modules/pi-zentui` stays on disk but is not loaded.

## Status line

`extensions/statusline.ts` replaces Pi's footer in every interactive session with two rows:

```
 ~/Projects/firstmate   main                                                   Recall: main
 claude-opus-5-5 anthropic ◆ low            ctx 1.2%/1.0M  ↑4 ↓261  cache 44%  $0.06 sub  56.4 tok/s
```

- Row 1: working directory, git branch, session name, and other extensions' `setStatus()` texts on the right.
- Row 2: model id, provider, and thinking level always lead, plus `⚡fast` when Codex fast mode is on. Context usage (yellow above 70%, red above 90%), token totals, cache hit rate, cost (`sub` when the provider uses a subscription login), and output speed fill the remaining width.
- Narrow panes drop cache, then tokens, then speed. When context usage and cost no longer fit beside the model, the stats move to a third row. The path shortens before the branch (`~/P/firstmate`, then `firstmate`). The model id stays visible at every width; the provider and then the thinking level give way only when the pane is narrower than the model cell itself.
- On a [pi-tiers](https://github.com/1yian/pi-tiers) tier, the model cell becomes the route, e.g. `auto → deep ↓2 → opus-5.5 xhigh · anthropic-2`: `auto` (or `auto?` when the classifier was unsure) when the tier was picked automatically, `↓N` when the first choice did not answer, the answering model and effort, and the account. Narrow panes drop the account, then the auto step, then the effort. Before the first request it shows `<tier> → …`.
- The footer measures output speed itself. A `tokens-per-second` status from the older standalone extension is hidden so it does not show twice.

No row starts with a shell or agent prompt glyph or draws a `─` rule or box border, so Firstmate's composer classifier keeps reading Pi's native editor. Live tmux captures classify an empty and a typed composer as `empty` and `pending` at 150, 80, 60, 45, and 32 columns, with Herdr-style (styled, no cursor) and tmux-style (cursor row) capabilities.

## Readable transcript

`extensions/fm-readable-ui.ts` loads automatically in every ordinary Pi session, including Firstmate supervisors, secondmates, and workers. It uses Pi's public Markdown transformer and tool-renderer APIs (Pi 1.0.1 or newer):

- Assistant prose starts each sentence on its own line. Code, tables, links, and abbreviations stay intact. Stored replies and model input are unchanged.
- Collapsed calls show `● tool(subject)` plus failure metadata. Subjects are clipped to 35 cells; very narrow terminals may use up to three rows. Ctrl+O restores each tool's own full rendering.
- Clicking a collapsed call expands that one call, and clicking it again collapses it; Ctrl+O still expands or collapses every call at once. Click handling is Pi's own (it wraps every tool renderer's output in a mouse region), so it needs Pi's default fullscreen mode, where Pi captures the mouse. In `--tui-mode regular` Pi does not capture the mouse, so there is no click target and Ctrl+O is the only toggle.
- Firstmate Calm remains authoritative while enabled. `/export` and `/share` retain stock tool rendering.

A separate classifier limitation predates this configuration: a Markdown table above the composer can be mistaken for an incomplete box and cause a cursorless `unknown` verdict. This is a safe refusal, not a false empty, and belongs to Firstmate's classifier rather than this configuration.

## Work tiers

`settings.json` installs [pi-tiers](https://github.com/1yian/pi-tiers) pinned to a tag, and `tiers.json` holds the personal chains. Select `tier/<name>` with `/model`, `--model`, or `/tier`; `/tiers` shows usable rungs and cooldowns. New sessions start on `tier/auto` (the settings default) unless a model is chosen; Firstmate homes, second mates, crewmates, OptChat, and no-mistakes select their tiers explicitly in their own local configuration.

- Work tiers (`tier/auto` picks one with Jev): `default`, `deep`, `visual`, `watch`, `quick`. Role tiers set by tool config: `orchestrator`, `supervisor`, `compact`, `reviewer`.
- `claude` expands to the `anthropic`, `anthropic-2`, and `anthropic-3` providers in order; accounts without a login are skipped. Extra accounts are [pi-multi-pass](https://github.com/hjanuschka/pi-multi-pass) subscriptions (`/subs add`, then `/login`); create no pools or chains there, so pi-tiers stays the only router. `pi-anthropic-auth.json` (linked as `extensions/pi-anthropic-auth/config.json`) gives those providers the same Claude subscription request shaping as `anthropic`, without which they bill as extra usage. Logins are per machine and stay in the local `auth.json`.
- The last rung is Baseten's pay-as-you-go DeepSeek V4.1 Flash 1017 (`baseten/deepseek-ai/DeepSeek-V4.1-Flash-1017`, $0.30 in / $1.20 out per 1M tokens) and shows `⚠` in the status line. It needs a `baseten` key in the local `auth.json` and, because Pi's catalog does not list the dated 1017 id yet, a matching `providers.baseten.models` entry in each machine's local `models.json` (a copy of the catalog's `DeepSeek-V4.1-Flash` entry with the 1017 id). OpenCode's free models refuse clients other than OpenCode itself (`403 FreeTierError`), so they are not in the chains.
- `tier/auto` needs a `typesafe` credential in the local `auth.json`; without one it uses `default`.
- Cooldowns and the decision log live in `~/.pi/agent/tiers/` (local state, not committed).

## Anthropic rate-limit fallback (macOS)

`extensions/anthropic-rate-limit-fallback.ts` waits until Pi's own retries are exhausted. An Anthropic rate-limit error (429, `rate_limit_error`, or a rate-limit message) switches the session to the registered `vertex-claude` model with the same id, then continues the interrupted turn automatically. For example, `anthropic/claude-opus-5-5` becomes `vertex-claude/claude-opus-5-5`.

A short transcript notice records the switch. The session stays on Vertex until you explicitly select another model. Non-rate-limit errors, cancellation, a missing matching model, or missing Vertex authentication do not switch providers. Configure the Vertex project and Google credentials as described in `extensions/vertex-claude/index.ts`; this extension does not provision them. The fallback remains macOS-only, including its Home Manager link. On Linux, only the work laptop loads `vertex-claude`; P620 loads neither.

## Optional supervisor memory

`extensions/fm-optchat/` ports the pinned OptChat integration from https://github.com/1yian/firstmate/pull/10. It requires `FM_HOME` (or `FM_ROOT_OVERRIDE`), the current directory resolving to that home, and `config/optchat.json` with `enabled: true`. With `FM_TASK_ID` set it returns before reading configuration or loading the package. Ordinary Pi projects, unconfigured homes, and disabled homes do not activate memory.

Use `optpi` from the Firstmate directory to launch Pi with `FM_HOME` set to that directory; plain `pi` remains unchanged. Start ordinary Pi sessions with `pi` as usual.

Nothing here enables the four Firstmate homes, imports sessions, downloads a package at startup, creates a profile, or changes account credentials. The existing per-home profile and package locations remain supported. Agents, connected-window listeners, child-history adoption, saved handoff recovery, and queued child reports are disabled. Current Firstmate instructions and approvals remain authoritative. Large recalled tool results point to a private lossless archive; canonical Pi results remain complete.

### Prepare before enabling

Download/extract the published `pi-optchat@0.7.2` package to private scratch, then run:

```sh
node ~/.pi/agent/optchat/package.mjs prepare \
  /absolute/path/to/published/package \
  "$FM_HOME/config/optchat/package"
```

On macOS, keep the full profile socket path (including `profiles/<name>/lock.sock`) within the system's 103-byte limit. Disabling connected windows does not disable OptChat's normal profile lock.

The helper requires Node and `patch`. It checks the complete pinned source inventory and SHA-256 fingerprints before applying the maintained patches in `manifest.json` order to a separate destination: `connected-windows.patch` (capability switches), `summary-labels.patch` (summaries keep who said what: tool output and records stay `echo`, and quoted old decisions are marked as quoted from a record rather than the user's words; automated `FIRSTMATE_OP` / `[firstmate] Operational notification` messages are labelled `notification`; throwaway wake and recovery identifiers are dropped; the memory page shows an unchanged short message once), and `compactor-fallback.patch` (rate-limit/overload failover). It validates and reuses an existing destination, never repairs or replaces it, so an already prepared copy must be prepared again at a new path after a patch changes. `manifest.json` also records the published npm integrity and each patch fingerprint. New summaries only: stored summaries are not rebuilt. Do not install unpatched OptChat as a global Pi package, which would bypass this loader's guards.

A home owner must provision its existing profile at `data/optchat/profiles/main/` with `AGENTS.md` and upstream `config.json` before enabling:

```json
{
  "enabled": true,
  "package": "config/optchat/package",
  "memoryHome": "data/optchat",
  "profile": "main",
  "thinking": "low"
}
```

Relative paths resolve against the Firstmate home, not the dotfiles. `compactorModel` optionally selects a model on the active supervisor's provider. Set `compactorProvider` to pin that provider independently, for example `"compactorProvider": "anthropic"` with `"compactorModel": "claude-haiku-5-5"`. This keeps the primary memory provider stable when the main session switches to Vertex. The loader validates the fixed profile and provider, and updates that profile's compactor settings. It does not support native Codex thread reuse.

### Compactor fallback chain

A rate-limited or overloaded compactor call retries the same input on `openai-codex/gpt-6-luna`, then `vertex-claude/claude-sonnet-5-5`. The Vertex extension also offers Haiku 5.5; the default fallback summary tier is Sonnet 5.5. Unregistered models and providers without configured authentication are skipped, including Vertex on P620. Other errors and cancellation retain the existing failure behavior. Successful fallbacks still contribute to the usage ledger; length-correction calls stay on that fallback, while a new compression starts with the primary again.

Override the chain with `compactorFallbacks` in the **profile's** `data/optchat/profiles/main/config.json`, alongside its existing `compactor` and `subagent` fields (not in `config/optchat.json`):

```json
"compactorFallbacks": [
  { "provider": "openai-codex", "model": "gpt-6-luna", "thinking": "low" },
  { "provider": "vertex-claude", "model": "claude-sonnet-5-5", "thinking": "low" }
]
```

Omitting the field uses the default chain; `[]` disables it. The supervisor loader preserves this profile field when updating its primary compactor. Restart after editing the profile. Already prepared copies must be re-prepared at a **new** destination, then explicitly repointed in the home's `config/optchat.json`; no live home is changed by updating these dotfiles:

```sh
node ~/.pi/agent/optchat/package.mjs prepare \
  /absolute/path/to/published/package \
  "$FM_HOME/config/optchat/package-rate-limit-fallback"
```

`/firstmate-memory` shows the current process/session activation receipt. `loaded` means initialization succeeded; `active` means outgoing conversation projection succeeded. The private receipt is `state/optchat-activation.json`. `/optchat browse` and `/optchat instructions` remain available; profile switching, imports, and mixed agent-control panels do not. Set `enabled: false` and restart to disable without deleting history.

The readable transcript implementation comes from https://github.com/1yian/firstmate/pull/9. Both integrations now live at user scope. Remove the old Firstmate project copies separately to avoid loading duplicate extensions.
