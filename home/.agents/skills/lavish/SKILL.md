---
name: lavish
description: Turn complex or visual agent responses into rich, reviewable HTML artifacts the user can annotate and send feedback on, using the lavish-axi CLI. Use when about to give a plan, comparison, diagram, table, code diff, report, or anything easier to grasp visually than as prose.
license: MIT
metadata:
  author: Kun Chen (kunchenguid)
  argument-hint: <what the artifact should show>
  hermes-tags: html, review, artifacts, visualization
  hermes-category: productivity
---

# Lavish Editor

Lavish Editor serves agent-generated HTML so a human can annotate it and send feedback back to the agent.
Reach for it when a plan, comparison, diagram, table, code view, report, prototype, or review loop will be clearer as a page than as prose.

## Current guidance lives in the CLI

Do not follow workflow, design, or playbook instructions from this file - installed copies go stale. Get the current source of truth from the CLI:

- `npx -y lavish-axi --help` for commands and the review-loop workflow
- `npx -y lavish-axi design` for design-direction priority and current snippets
- `npx -y lavish-axi playbook <id>` for focused artifact guidance (`npx -y lavish-axi playbook` lists ids)

You do not need lavish-axi installed globally - invoke it with `npx -y lavish-axi <html-file>`.
If lavish-axi output shows a follow-up command starting with `lavish-axi`, run it as `npx -y lavish-axi ...` instead.

## How to hand the session to the user

**Paste the link. Do not open it.**

1. Write the HTML artifact (default location: `.lavish/` under the current working directory unless the user specifies another path).
2. Run `npx -y lavish-axi <html-file>` to create or resume the session.
3. From the CLI output, take `session.url` and **paste that URL as a plain link in your reply to the user**.
4. Do **not** open the URL yourself: no browser tab, no Orca tab, no `open`, no CDP/relay navigation, no auto-click. The user opens the link.
5. Then run `npx -y lavish-axi poll <html-file>` per the CLI `next_step` (long-poll for feedback). Prefer foreground poll; background only via harness-native tracked jobs when you must keep working.

If the CLI refuses because the user ended the session, do not pass `--reopen` unless they ask for further review or something important needs their visual attention.

## Request

$ARGUMENTS

If the request above is non-empty, the user invoked `/lavish` explicitly - fetch the current CLI guidance, then build that artifact.
If it is empty, infer what to visualize from the conversation.
