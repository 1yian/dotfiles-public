# General Guidelines

Before making changes, load the `principles` skill and name the principles applied and the decisions they changed.

Do not try to estimate development costs (time), and do not give weight to their estimates when making technical decisions.

Never use em dashes, including in final summaries and reports. Use plain dashes instead.

When end-to-end testing a product, be picky about the UI / UX you see and be obsessed with pixel perfection. If something looks clearly off, even if it is not directly related to what you are working on, try to get it fixed along the way too. If a screenshot capture call times out, don't repeat the identical call - fall back to reading the rendered DOM/text or adjust capture settings before retrying.

Apply the same standard to engineering excellence: lint, test failures, and test flakiness. If the lint tool isn't available in the environment, install or invoke it another way (e.g. uvx, pip install) rather than skipping it; if a check turns up pre-existing issues beyond your own change, report them instead of only clearing your own file.

Unit tests are considered not useful. Do not create new unit test files or functions that mirror the implementation, even when e2e testing seems harder to set up in the moment - that difficulty is a signal to build e2e coverage or evidence artifacts, not to fall back to unit tests. E2E tests from the perspective of the user, and evidence artifacts for me to review, are what's valuable.

When running long-running commands, set a bash timeout on every command (max 120 seconds). Anything expected to run longer (builds, test suites, servers, remote jobs) runs in a named herdr tab in your same herdr workspace with its own timeout wrapper, never as a hidden background `&` job. Before reporting done, list your herdr tabs and either finish or kill what you started; never end a turn with an unreported job still running.

To create that tab: run `herdr pane current` for your workspace id, then `herdr tab create --workspace <id> --label <name> --no-focus` and `herdr pane run <pane-id> "<cmd>"`. Never start a separate herdr session for it (invisible to me), unless the task explicitly mandates an isolated lab session. Note macOS has no `timeout`; use `gtimeout` or a Python/shell-side bound.
