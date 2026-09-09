# humanizer deterministic detectors

A pre-LLM pattern pass for the `humanizer` skill. Catches the mechanically
detectable tells that `SKILL.md` already describes in prose, so they are found
before any model judgment is spent on them.

**Detection only. It never rewrites.** That separation is the point: offline
checks first, online refinement after. Adopted from the Impeccable idea in
`evals/2026-09-08-reddit-ideas-list.md` (ranked adoption #1), whose own framing is
"Detection != Generation; offline checks before online refinement".

```
python tools/humanizer-detectors/detect.py FILE [FILE...]
python tools/humanizer-detectors/detect.py -          # stdin
python tools/humanizer-detectors/detect.py --strict F  # exit 1 on any DEFINITE
```

Stdlib only, no install. Fenced code blocks are skipped -- most documents here
embed shell or source, and flagging that as prose would make the tool unusable.

## Severity

| | Meaning |
|---|---|
| `DEFINITE` | A tell by the skill's own definition. Near-zero false positives. |
| `ADVISORY` | A signal needing a human look. Ordinary prose can legitimately trip it. |

The split exists so `--strict` has something honest to gate on. Rules that cannot
be made precise are ADVISORY rather than dropped, and rules that cannot be made
meaningful at all are left out entirely rather than approximated badly.

## Coverage against SKILL.md's 32 numbered patterns

**Implemented** (rule numbers match the skill's own sections):

| # | Pattern | Severity | How |
|---|---|---|---|
| 3 | Participle tails | DEFINITE | Comma + participle from the skill's list. Anchored on the comma; a bare "showcasing" is rule 7's business. |
| 7 | AI vocabulary | DEFINITE / ADVISORY | The skill's verbatim list. Entries it qualifies by part of speech ("highlight (verb)", "key (adjective)") are ADVISORY, since telling them apart needs tagging this does not do. |
| 9 | Negative parallelism | DEFINITE | "not just", "not only ... but", "not merely", "isn't just", plus tailing negations ("..., no guessing."). |
| 10 | Rule of three | ADVISORY | "X, Y, and Z" with multi-word items. Approximate by construction -- a triad is ordinary English as often as it is a tell. |
| 14 | Em/en dashes | DEFINITE | Literal `—` / `–`. The skill's hardest rule. |
| 15 | Boldface density | ADVISORY | 3+ bold spans on one line. |
| 17 | Title Case headings | ADVISORY | Heading lines where >=70% of words are capitalised. |
| 18 | Emojis | DEFINITE | Unicode category `So` or codepoint >= U+1F000, so a new emoji cannot silently pass. |
| 19 | Curly quotes | DEFINITE | Literal `‘ ’ “ ”`. |
| 23 | Filler phrases | DEFINITE | The skill's verbatim list. |
| 24 | Excessive hedging | DEFINITE | Two adjacent hedges ("could potentially"). A single hedge is fine and is not flagged. |
| 26 | Hyphenated pairs | DEFINITE | **Predicate position only** ("the report is high-quality"). The skill keeps attributive hyphens, so flagging those would contradict it. |

**Deliberately not implemented** -- these need judgment a regex cannot supply, and
a false positive costs more than a miss: 1, 2 (significance/notability inflation),
4 (promotional language), 5 (vague attributions), 6 (challenges/prospects
sections), 8 (copula avoidance), 11 (elegant variation), 12 (false ranges), 13
(passive voice -- needs POS tagging to do honestly), 16 (inline-header lists),
20-22 (collaborative artifacts, cutoff disclaimers, sycophancy), 25 (generic
conclusions), 27-32 (authority tropes, signposting, fragmented headers,
diff-anchored writing, manufactured punchlines, aphorism formulas).

Those remain the model's job. This pass is the cheap half, not a replacement.

## Validation (2026-09-09)

Ground truth is the skill's own Before/After example pairs -- the "After" text is
by definition what humanizer considers clean.

- **Before text:** 15 findings, catching every planted tell.
- **After text:** clean. Zero findings.
- **Real prose:** `loops/README.md` (214 lines) and `domains/loop-design.md` (251
  lines) -> 5 DEFINITE findings total, **all five genuine** on inspection (two em
  dashes, a "not merely", a "not just"). No false positives in 465 lines.

Re-run that check after changing any rule. A detector that disagrees with the
skill it serves is worse than no detector.

## Keeping this in step with the skill

Every rule is derived from a numbered SKILL.md section and carries its number. If
the skill's word lists change, change these too.

Note the skill itself is a **plugin-managed fork** at `~/.agents/skills/humanizer`
(not a git repo -- see `forks/humanizer-voice-calibration.md`), so its lists can
be replaced by an update without warning. This tool lives here, in the synced
store, precisely so it is not subject to that.

## Open decision: wiring it into the skill

Not done, deliberately. The obvious integration is a pointer in humanizer's
`SKILL.md` workflow telling it to run this first -- but `SKILL.md` is inside the
volatile fork, so that edit would be a **second** unbacked hand-modification of a
file a plugin update reverts. That is the exact failure already recorded in
`forks/humanizer-voice-calibration.md`, where a stale backup would have silently
restored worse content.

So the tool stands alone until someone decides between:
1. Fork `SKILL.md` again and extend the fork record to cover both edits.
2. Invoke it from a convention outside the skill (CLAUDE.md, or a hook).
3. Leave it manual.
