#!/usr/bin/env python3
"""Deterministic pre-LLM detector pass for the `humanizer` skill.

Catches the mechanically detectable AI-writing tells that humanizer's SKILL.md
already describes in prose, so pattern-matchable hits are found before any model
judgment is spent on them. Detection only -- it never rewrites. That split is the
point: offline checks first, online refinement after.

Every rule here is derived from a NUMBERED section of humanizer's SKILL.md, and
each carries its section number. If the skill's lists change, change these too --
a detector that disagrees with the skill it serves is worse than no detector.

Rules NOT implemented, deliberately, because they need judgment a regex cannot
supply and a false positive here costs more than a miss:
    1, 2   significance/notability inflation      -- semantic
    4      promotional language                   -- semantic
    5      vague attributions ("experts say")     -- needs referent resolution
    6      "challenges and future prospects"      -- structural, whole-document
    8      copula avoidance                       -- needs parsing
    11     elegant variation (synonym cycling)    -- needs coreference
    12     false ranges                           -- semantic
    13     passive voice                          -- needs POS tagging to do honestly
    16     inline-header vertical lists           -- structural, context-dependent
    20-22  collaborative artifacts, cutoff disclaimers, sycophancy -- semantic
    25     generic positive conclusions           -- semantic
    27-32  authority tropes, signposting, fragmented headers,
           diff-anchored writing, manufactured punchlines, aphorisms -- semantic

Usage:
    python detect.py FILE [FILE...]
    python detect.py -            # read stdin
    python detect.py --strict FILE   # exit 1 if any DEFINITE finding

Severity:
    DEFINITE  a tell by the skill's own definition; near-zero false positives.
    ADVISORY  a signal that needs a human look; real prose can trip it.
"""
from __future__ import annotations

import re
import sys
import unicodedata

DEFINITE = "DEFINITE"
ADVISORY = "ADVISORY"

# -- §7 Overused "AI Vocabulary" Words -------------------------------------
# Verbatim from SKILL.md §7. Entries the skill qualifies by part of speech
# ("highlight (verb)", "key (adjective)") are matched as bare words and marked
# ADVISORY, since distinguishing them needs tagging we deliberately do not do.
AI_VOCAB_DEFINITE = [
    "delve", "interplay", "intricacies", "intricate", "pivotal", "tapestry",
    "testament", "underscore", "underscores", "underscored", "showcase",
    "showcases", "showcased", "garner", "garners", "garnered", "fostering",
    "emphasizing", "enduring", "vibrant",
]
AI_VOCAB_ADVISORY = [
    "actually", "additionally", "crucial", "enhance", "enhances", "enhanced",
    "highlight", "highlights", "highlighted", "key", "landscape", "valuable",
    "align with", "aligns with",
]

# -- §3 Superficial analyses with -ing endings -----------------------------
# The tell is a participle phrase tacked onto a finished sentence, so anchor on
# a preceding comma. Bare "showcasing" elsewhere is §7's business, not this rule.
PARTICIPLE_TAILS = [
    "highlighting", "underscoring", "emphasizing", "ensuring", "reflecting",
    "symbolizing", "contributing to", "cultivating", "fostering",
    "encompassing", "showcasing",
]

# -- §23 Filler phrases ----------------------------------------------------
FILLER = [
    "in order to", "due to the fact that", "at this point in time",
    "in the event that", "has the ability to", "have the ability to",
    "it is important to note that", "it should be noted that",
    "it is worth noting that", "needless to say",
]

# -- §26 Hyphenated word pairs ---------------------------------------------
# The skill keeps ATTRIBUTIVE hyphens and drops PREDICATE ones, so only the
# predicate position is a finding: "the report is high-quality".
HYPHEN_PAIRS = [
    "third-party", "cross-functional", "client-facing", "data-driven",
    "decision-making", "well-known", "high-quality", "real-time", "long-term",
    "end-to-end",
]

HEDGES = ["could", "might", "may", "possibly", "potentially", "perhaps",
          "arguably", "somewhat", "relatively", "fairly", "seemingly"]


def _iter_lines(text: str):
    for n, line in enumerate(text.split("\n"), 1):
        yield n, line


def _add(out, line_no, col, rule, severity, detail):
    out.append({"line": line_no, "col": col, "rule": rule,
                "severity": severity, "detail": detail})


def scan(text: str) -> list[dict]:
    findings: list[dict] = []
    in_fence = False

    for n, line in _iter_lines(text):
        # Fenced code is not prose. Skipping it is what keeps this usable on
        # documents that embed shell or source, which most of ours do.
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        # §14 Em/en dashes -- the skill's hardest rule ("Cut Them").
        for m in re.finditer(r"[—–]", line):
            _add(findings, n, m.start() + 1, "14 em/en dash", DEFINITE, m.group(0))

        # §19 Curly quotation marks.
        for m in re.finditer(r"[‘’“”]", line):
            _add(findings, n, m.start() + 1, "19 curly quote", DEFINITE, m.group(0))

        # §18 Emojis. Match by Unicode category/range rather than a list, so a
        # new emoji does not silently pass.
        for i, ch in enumerate(line):
            if ord(ch) >= 0x1F000 or unicodedata.category(ch) == "So":
                _add(findings, n, i + 1, "18 emoji", DEFINITE, ch)

        low = line.lower()

        # §7 AI vocabulary.
        for word in AI_VOCAB_DEFINITE:
            for m in re.finditer(rf"\b{re.escape(word)}\b", low):
                _add(findings, n, m.start() + 1, "7 AI vocabulary", DEFINITE, word)
        for word in AI_VOCAB_ADVISORY:
            for m in re.finditer(rf"\b{re.escape(word)}\b", low):
                _add(findings, n, m.start() + 1, "7 AI vocabulary", ADVISORY, word)

        # §9 Negative parallelisms and tailing negations.
        for pat, label in [
            (r"\bnot just\b", "not just"),
            (r"\bnot only\b.*\bbut\b", "not only ... but"),
            (r"\bnot merely\b", "not merely"),
            (r"\bisn't just\b", "isn't just"),
            (r"\bit's not just\b", "it's not just"),
            (r",\s*no\s+\w+(?:ing|s)?\s*[.!?]", "tailing negation"),
        ]:
            for m in re.finditer(pat, low):
                _add(findings, n, m.start() + 1, "9 negative parallelism", DEFINITE, label)

        # §3 Participle tails.
        for word in PARTICIPLE_TAILS:
            for m in re.finditer(rf",\s+{re.escape(word)}\b", low):
                _add(findings, n, m.start() + 1, "3 participle tail", DEFINITE, f", {word}")

        # §23 Filler phrases.
        for phrase in FILLER:
            for m in re.finditer(rf"\b{re.escape(phrase)}\b", low):
                _add(findings, n, m.start() + 1, "23 filler phrase", DEFINITE, phrase)

        # §24 Excessive hedging -- a single hedge is fine; a stack is the tell.
        for m in re.finditer(rf"\b({'|'.join(HEDGES)})\s+({'|'.join(HEDGES)})\b", low):
            _add(findings, n, m.start() + 1, "24 hedge stack", DEFINITE, m.group(0))

        # §26 Hyphenated pair in PREDICATE position only.
        for pair in HYPHEN_PAIRS:
            for m in re.finditer(rf"\b(?:is|are|was|were|be|been)\s+{re.escape(pair)}\b", low):
                _add(findings, n, m.start() + 1, "26 predicate hyphen", DEFINITE, m.group(0))

        # §15 Boldface overuse.
        bolds = len(re.findall(r"\*\*[^*]+\*\*", line))
        if bolds >= 3:
            _add(findings, n, 1, "15 boldface density", ADVISORY, f"{bolds} bold spans on one line")

        # §10 Rule of three. Approximate by construction, hence ADVISORY: an
        # "X, Y, and Z" list is ordinary English as often as it is a tell.
        # Items may be multi-word -- an earlier single-word-only pattern missed
        # the skill's own example ("keynote sessions, panel discussions, and
        # networking opportunities"), which is the canonical case.
        item = r"[\w'-]+(?: [\w'-]+){0,3}"
        for m in re.finditer(rf"\b{item}, {item},? and {item}\b", low):
            _add(findings, n, m.start() + 1, "10 rule of three", ADVISORY, m.group(0)[:48])

        # §17 Title Case in headings.
        if line.startswith("#"):
            words = re.findall(r"\b[A-Za-z][a-z']+\b", line)
            caps = [w for w in re.findall(r"\b[A-Z][a-z']+\b", line)]
            if len(words) >= 4 and len(caps) >= max(3, int(len(words) * 0.7)):
                _add(findings, n, 1, "17 title case heading", ADVISORY, line.strip()[:48])

    return findings


def render(path: str, findings: list[dict]) -> str:
    if not findings:
        return f"{path}: clean (no deterministic tells)\n"
    out = [f"{path}: {len(findings)} finding(s)"]
    for f in sorted(findings, key=lambda x: (x["line"], x["col"])):
        # ASCII only: a section sign renders as a replacement char under the
        # Windows console's default codepage, which is where this mostly runs.
        out.append(f"  {f['line']}:{f['col']}  [{f['severity']}] rule {f['rule']} -- {f['detail']}")
    definite = sum(1 for f in findings if f["severity"] == DEFINITE)
    out.append(f"  ({definite} definite, {len(findings) - definite} advisory)")
    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if a != "--strict"]
    strict = "--strict" in argv[1:]
    if not args:
        print(__doc__.strip().split("Usage:")[1].strip(), file=sys.stderr)
        return 2

    worst = 0
    for path in args:
        if path == "-":
            text, label = sys.stdin.read(), "<stdin>"
        else:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text, label = fh.read(), path
        findings = scan(text)
        sys.stdout.write(render(label, findings))
        if strict and any(f["severity"] == DEFINITE for f in findings):
            worst = 1
    return worst


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
