#!/usr/bin/env python3
"""Audit fleet pin consistency. Add --latest to compare npm pins with the registry.

Read-only: no installs, updates, credentials, or daemon/session operations.
"""

import argparse
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def npm_specs(text):
    return dict(re.findall(r"([@a-zA-Z0-9/._-]+)@(\d+\.\d+\.\d+)", text))


def pi_packages(path):
    settings = json.loads((ROOT / path).read_text())
    sources = [p if isinstance(p, str) else p["source"] for p in settings["packages"]]
    for source in sources:
        if not re.fullmatch(r"npm:[@a-zA-Z0-9/._-]+@\d+\.\d+\.\d+", source):
            raise ValueError(f"{path}: unpinned Pi package {source}")
    return npm_specs("\n".join(sources))


def audit():
    linux = npm_specs((ROOT / "linux-agents.sh").read_text())
    packages = pi_packages("home/.pi/agent/settings.json")
    fleet = (ROOT / "hosts/p620-fleet-packages.nix").read_text()
    herdr = re.search(r'version = "([^"]+)"', fleet)[1]
    treehouse = re.search(r'archiveTool "treehouse" "([^"]+)"', fleet)[1]
    no_mistakes = re.search(r'archiveTool "no-mistakes" "([^"]+)"', fleet)[1]
    gcloud = re.search(r'version = "([^"]+)"', (ROOT / "hosts/p620.nix").read_text())[1]
    rows = {
        "Herdr": herdr,
        "treehouse": treehouse,
        "no-mistakes": no_mistakes + " public release",
        "Pi": linux["@earendil-works/pi-coding-agent"],
        "Claude Code / Codex": linux["@anthropic-ai/claude-code"]
        + " / "
        + linux["@openai/codex"],
        "gh-axi / chrome-devtools-axi": linux["gh-axi"]
        + " / "
        + linux["chrome-devtools-axi"],
        "chrome-devtools-mcp (Linux browser adapter)": linux["chrome-devtools-mcp"],
        "lavish-axi / tasks-axi / quota-axi": " / ".join(
            linux[p] for p in ["lavish-axi", "tasks-axi", "quota-axi"]
        ),
        "Higgsfield / gnhf": linux["@higgsfield/cli"] + " / " + linux["gnhf"],
        "Twilio / Vercel": linux["twilio-cli"] + " / " + linux["vercel"],
        "gcloud": gcloud,
    }
    readme = (ROOT / "README.md").read_text()
    for label, value in rows.items():
        if f"| {label} | {value} |" not in readme:
            raise ValueError(f"README pin table mismatch: {label} should be {value}")
    print(
        f"PASS: {len(linux)} Linux npm pins, "
        f"{len(packages)} shared Pi packages, {len(rows)} README rows"
    )
    for name, version in {**linux, **packages}.items():
        print(f"{name}@{version}")
    return {**linux, **packages}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--latest", action="store_true", help="query npm's current latest tags"
    )
    args = parser.parse_args()
    pins = audit()
    if args.latest:
        for name, version in pins.items():
            with urllib.request.urlopen(
                f"https://registry.npmjs.org/{name}/latest", timeout=15
            ) as response:
                latest = json.load(response)["version"]
            print(
                f"{'CURRENT' if version == latest else 'DIFFERS'}: {name} pinned={version} latest={latest}"
            )


if __name__ == "__main__":
    main()
