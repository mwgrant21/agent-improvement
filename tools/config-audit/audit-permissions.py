#!/usr/bin/env python3
"""Audit Claude Code permission allow-rules for entries that have grown over-broad.

`/fewer-permission-prompts` only ever WIDENS the allowlist -- it adds rules to stop
prompts and never revisits them. Nothing looks back at what accumulated. This does,
periodically and read-only.

Report-only by design. It never edits settings.json: an allow rule is a deliberate
decision about risk, and a tool that silently narrowed one would be making that
decision on the user's behalf from less context than they had.

    python audit-permissions.py                  # audits ~/.claude/settings.json
    python audit-permissions.py PATH [PATH...]
    python audit-permissions.py --strict         # exit 1 if any HIGH finding
"""
from __future__ import annotations

import json
import os
import sys

HIGH, REVIEW, INFO = "HIGH", "REVIEW", "INFO"

# Commands whose blast radius does not stay inside the working tree. A `:*` rule on
# any of these grants far more than the task that prompted it.
HIGH_BLAST = {
    "rm": "deletes anything reachable, with no undo",
    "rmdir": "removes directories",
    "del": "deletes anything reachable",
    "rd": "removes directories",
    "curl": "arbitrary network egress; can exfiltrate or fetch-and-run",
    "wget": "arbitrary network egress",
    "iwr": "arbitrary network egress (Invoke-WebRequest)",
    "irm": "arbitrary network egress (Invoke-RestMethod)",
    "chmod": "changes permissions anywhere",
    "icacls": "changes Windows ACLs anywhere",
    "reg": "edits the registry",
    "schtasks": "creates scheduled tasks that outlive the session",
    "npm": "runs arbitrary lifecycle scripts on install",
    "pip": "runs arbitrary setup code on install",
    "docker": "container runtime, escapes most sandboxing assumptions",
}

# Git subcommands that rewrite or publish history rather than building on it.
GIT_IRREVERSIBLE = {
    "push": "publishes; --force can destroy remote history",
    "reset": "--hard discards uncommitted work",
    "clean": "-fd deletes untracked files with no undo",
    "rebase": "rewrites history",
    "filter-branch": "rewrites all history",
    "reflog": "the recovery net itself",
}


def parse_rule(rule: str):
    """'Bash(git add:*)' -> ('Bash', 'git add', True). Non-parenthesised -> (tool, None, True)."""
    if "(" not in rule or not rule.endswith(")"):
        return rule, None, True
    tool, inner = rule.split("(", 1)
    inner = inner[:-1]
    wild = inner.endswith(":*") or inner.endswith("*")
    body = inner[:-2] if inner.endswith(":*") else (inner[:-1] if inner.endswith("*") else inner)
    return tool, body.strip(), wild


def audit(rules: list[str]) -> list[tuple[str, str, str]]:
    out: list[tuple[str, str, str]] = []
    seen: list[tuple[str, str | None]] = []

    for rule in rules:
        tool, body, wild = parse_rule(rule)

        # A tool-only rule ("Bash", "Read") allows every invocation of it.
        if body is None:
            sev = HIGH if tool in ("Bash", "PowerShell", "Write", "Edit") else REVIEW
            out.append((sev, rule, f"grants ALL {tool} calls -- no argument constraint at all"))
            seen.append((tool, None))
            continue

        head = body.split()[0] if body.split() else body

        if head in HIGH_BLAST and wild:
            out.append((HIGH, rule, f"`{head}` {HIGH_BLAST[head]}"))
        elif head == "git" and len(body.split()) > 1:
            sub = body.split()[1]
            if sub in GIT_IRREVERSIBLE:
                out.append((HIGH, rule, f"`git {sub}` {GIT_IRREVERSIBLE[sub]}"))
        elif head == "git" and wild and len(body.split()) == 1:
            out.append((HIGH, rule, "`git:*` covers push/reset/clean -- every irreversible subcommand"))

        # An in-place editor with a wildcard edits ANY file the process can reach,
        # which is a wider grant than the file-editing tools it sits beside.
        if head in ("sed", "perl") and wild and "-i" in body:
            out.append((REVIEW, rule, f"`{body}` edits any reachable file in place, outside Edit/Write review"))

        seen.append((tool, body))

    # Subsumption: a broader rule makes a narrower one dead weight, and dead rules
    # hide what is actually being granted.
    for tool_a, body_a in seen:
        if body_a is None:
            for tool_b, body_b in seen:
                if tool_b == tool_a and body_b is not None:
                    out.append((INFO, f"{tool_b}({body_b}:*)", f"redundant: {tool_a} alone already grants it"))
            continue
        for tool_b, body_b in seen:
            if tool_a == tool_b and body_b is not None and body_a != body_b and body_b.startswith(body_a + " "):
                out.append((INFO, f"{tool_b}({body_b}:*)", f"redundant: covered by the broader {tool_a}({body_a}:*)"))

    return out


def run(path: str) -> list[tuple[str, str, str]]:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    perms = data.get("permissions", {})
    rules = perms.get("allow", []) or []
    findings = audit(rules)

    print(f"{path}: {len(rules)} allow rule(s), {len(findings)} finding(s)")
    for rule in rules:
        print(f"  rule: {rule}")
    if perms.get("defaultMode"):
        print(f"  defaultMode: {perms['defaultMode']}")
    if not findings:
        print("  -> nothing over-broad found")
        return findings
    print()
    for sev in (HIGH, REVIEW, INFO):
        for s, rule, why in findings:
            if s == sev:
                print(f"  [{sev}] {rule}\n         {why}")
    return findings


def main(argv: list[str]) -> int:
    strict = "--strict" in argv[1:]
    paths = [a for a in argv[1:] if not a.startswith("--")]
    if not paths:
        paths = [os.path.expanduser("~/.claude/settings.json")]
    worst = 0
    for p in paths:
        if not os.path.exists(p):
            print(f"{p}: not found", file=sys.stderr)
            continue
        findings = run(p)
        if strict and any(s == HIGH for s, _, _ in findings):
            worst = 1
    return worst


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
