# Fork record: humanizer "Voice Calibration"

**Authoritative recovery source for a hand-applied local fork.** Supersedes the
copy embedded in `docs/plans/2026-08-15-voice-profile-persistence.md`, which is a
historical implementation plan and has since drifted (see "Why this file exists").

- **Forked file:** `~/.claude/skills/humanizer/SKILL.md` (a symlink to
  `~/.agents/skills/humanizer/SKILL.md` on home-matt), section `## Voice Calibration`
- **Upstream:** `blader/humanizer` v2.9.1
- **Applied:** 2026-08-15
- **Design:** `docs/specs/2026-08-15-voice-profile-persistence-design.md`
- **Profile data:** `voice-profiles/` in this store (git-synced, unaffected by any of this)

## Why this file exists

The fork lives in `~/.agents/skills/humanizer/`, which is **not a git repository** on
either machine. A plugin update overwrites the section back to stock with no warning.

The fork's own pointer file (`docs/voice-profiles.md`) carries reapplication text, but
it sits *inside the directory that gets overwritten*, so it disappears exactly when it
is needed. The 2026-08-15 plan does hold a copy in this store -- but on 2026-09-09 that
copy was found to have drifted from what is live: it still said the register file and
`matt-default.md` should "apply both together", while the live text had been refined to
"follow the register file's own stated precedence ... Do not blindly merge both in
full." Restoring from the plan would have silently reinstated the blind-merge behaviour
the current wording exists to prevent.

A backup that quietly restores worse content is the failure mode this file closes.

## Verbatim current text

Replace the whole `## Voice Calibration` section of `SKILL.md` with everything between
the markers. Copy verbatim -- do not reflow or re-punctuate.

<!-- BEGIN VERBATIM -->
## Voice Calibration

> **Local fork note (2026-08-15):** this section was hand-modified from upstream `blader/humanizer` v2.9.1 to add persisted-profile support (see `docs/voice-profiles.md` in this same folder). A plugin update will silently overwrite this section back to stock behavior with no warning. If Voice Calibration stops finding `~/agent-improvement/voice-profiles/` after an update, this note is why. See the pointer file for exact reapplication text.

Before rewriting, establish which voice to match, in this order of precedence:

1. **An inline sample in this conversation** (the user's own previous writing, pasted or attached). Always wins if present.
2. **A persisted voice profile.** Check `~/agent-improvement/voice-profiles/` for a profile matching the requested register (for example, "as a Jira ticket" -> `matt-jira.md`), or `matt-default.md` if no register is named and that file exists. Load and apply it. If the register file states it builds on `matt-default.md`, follow the register file's own stated precedence for what it inherits versus overrides. Do not blindly merge both in full: the register file is authoritative for its stated inheritance scope.
3. **Neither is available:** use the default behavior below.

When using an inline sample:

1. Read the sample first. Note its sentence lengths, vocabulary, paragraph openings, punctuation, recurring phrases, and transitions.
2. Match those habits instead of merely deleting AI patterns. Do not upgrade casual words or regularize deliberate quirks.

A sample or persisted profile outranks this skill's style rules, including the em dash rule in §14: if it uses em dashes, keep them at roughly its frequency. Matching the author beats scrubbing the tell.

<!-- END VERBATIM -->

## Drift check

Run after any plugin update, and before trusting this file as a backup. Prints
IDENTICAL or a diff:

```bash
python - <<'EOF'
import io,re,os,difflib
skill=io.open(os.path.expanduser('~/.claude/skills/humanizer/SKILL.md'),encoding='utf-8').read()
rec=io.open(os.path.expanduser('~/agent-improvement/forks/humanizer-voice-calibration.md'),encoding='utf-8').read()
live=re.search(r'^## Voice Calibration
(.*?)(?=^## )',skill,re.S|re.M).group(0).rstrip()
want=rec.split('<!-- BEGIN VERBATIM -->')[1].split('<!-- END VERBATIM -->')[0].strip('
')
print('IDENTICAL' if live==want else '
'.join(difflib.unified_diff(want.split('
'),live.split('
'),'record','live',lineterm='')))
EOF
```

A diff means one of two things, and they need opposite responses:
- **live is stock upstream** -> an update reverted the fork; reapply the verbatim text above.
- **live is a refinement** -> someone improved the section; update THIS file, or the next
  restore silently undoes their work. That is the drift found on 2026-09-09.
