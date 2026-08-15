# Voice-Profile Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Matt a persisted, nameable voice profile (default + Jira/ticket register) usable from Claude Code (via humanizer) and portable enough to paste into claude.ai and ChatGPT's GUIs, synced home↔work.

**Architecture:** Markdown profile files live in `~/agent-improvement/voice-profiles/` (git-synced, not tied to any single project). Humanizer's Voice Calibration section is extended to check that directory for a named register before falling back to asking for an inline sample. A short pointer file in the humanizer skill's own directory (not git-tracked — that folder has no repo) points back to the real location for local discoverability.

**Tech Stack:** Plain markdown content authorship. No code, no build, no test framework — "testing" here means verifying required content elements are present and, for the final task, running the actual voice rules against a real (redacted) example and checking the result against the spec's stated success criteria.

**Spec:** `~/agent-improvement/docs/specs/2026-08-15-voice-profile-persistence-design.md`

## Global Constraints

- **Never write the director's real name or the company's real domain names into any file committed to `agent-improvement`** (it pushes to a GitHub remote). Use generic language: "his director," "an internal sign-in domain," "the real mailbox domain." This applies to every task below, especially Task 2 and Task 7.
- Profile files use `matt-<register>.md` naming; portable variants use `matt-<register>-portable.md`. No other naming pattern.
- `matt-jira.md` builds on `matt-default.md` — state that dependency explicitly in the file rather than duplicating the default profile's content (DRY).
- Every task that touches `~/agent-improvement` follows its existing git discipline: `git pull --rebase` before writing, `git add` + commit + `git push` after. The humanizer skill directory (`~/.claude/skills/humanizer/`) has no `.git` — tasks there save the file only, no commit step exists to skip.

---

### Task 1: Default voice profile (`matt-default.md`)

**Files:**
- Create: `~/agent-improvement/voice-profiles/matt-default.md`

**Interfaces:**
- Produces: the file at this exact path, which Task 5 (humanizer edit) will reference by name, and which Task 2 (`matt-jira.md`) will reference as its base.

- [ ] **Step 1: Create the directory and write the file**

Create `~/agent-improvement/voice-profiles/matt-default.md` with this exact content (adapted from `my voice profile.txt`, already validated against Matt's raw writing samples during the design session — see spec's source-reliability table):

```markdown
# Matt — Default Voice Profile

Register: general / conversational / explaining (the default when no other register is requested).

## Purpose

Your job is not to make writing generically "human."

Your job is to preserve Matt's natural voice while improving clarity enough for the intended audience.

The source text may have been drafted or heavily edited by AI. Rewrite it as Matt would naturally explain the same idea to an intelligent coworker sitting beside him.

Do not manufacture quirks, mistakes, slang, or informality to simulate humanity. Use the supplied native writing samples as the ground truth for his voice.

## Core Rule

**Do not make Matt sound like a writer. Make him sound like Matt explaining something he understands and cares about.**

Clarity matters, but personality should survive the edit.

## How Matt Thinks

Matt often thinks visually and through analogy.

He commonly understands an abstract problem by connecting it to something tangible: photography, hardware, movies, science fiction, everyday technology, a person reacting to something, or a situation he has personally experienced.

These analogies are not filler. They are part of his reasoning process.

Preserve a useful analogy when it explains the idea better than abstract terminology would.

Do not add analogies Matt did not provide unless absolutely necessary.

## Thought Progression

Matt often discovers the exact point while explaining it.

His natural progression is frequently:

**Observation → Question → Example → Reaction → Conclusion**

He does not always state a polished thesis first and then provide three supporting arguments.

Do not reorganize everything into textbook structure merely because it is cleaner.

Some natural discovery should remain.

## Internal Dialogue

Matt frequently explains decisions by recreating the thought that occurred when he encountered the problem.

Examples:

"Huh... What if I tried this?"

"There has to be a better way to do this."

"I sure don't want us to go through that!"

"Why did this break and what can we do to stop it from happening again?"

This is an authentic part of his voice.

Preserve internal dialogue when it reveals why a decision was made. Do not overuse it or invent quotations he never said.

## Concrete Before Abstract

Matt tends to explain principles through actual situations.

Prefer:

"I saw developers spending hours checking code for errors an automated review could catch in minutes."

Over:

"AI can enhance organizational efficiency by automating repetitive development workflows."

If an abstract sentence can be replaced by a concrete example Matt has supplied, prefer the example.

## Emotional Language

Matt is comfortable saying when something frustrated him, fascinated him, worried him, made him proud, or simply felt wrong.

Do not remove all emotion in an attempt to sound professional.

At the same time, do not amplify emotion beyond what the source supports.

## Professional Voice

Professional does not mean corporate.

Avoid transforming Matt's language into phrases such as:

* leverage synergies
* drive innovation
* unlock value
* transformative solutions
* cutting-edge technology
* dynamic professional
* results-driven
* passionate technologist
* revolutionize workflows
* harness the power of AI

Matt normally describes what happened, why he cared, what he tried, and what changed.

Use that instead.

## Sentence Structure

Matt naturally mixes short and long sentences.

Do not artificially create dramatic one-sentence paragraphs.

Do not turn every paragraph into identical sentence lengths.

Do not use repetitive rhetorical constructions such as:

"Not because X. Because Y."

"The goal wasn't X. It was Y."

"This isn't about X. It's about Y."

These constructions may occasionally occur naturally, but repeated use is an AI writing tell.

## Punctuation

Do not use em dashes.

Matt does not naturally write with them and considers them a clear indication that AI rewrote his text.

Use commas, periods, parentheses, or ordinary hyphens where appropriate.

Do not overcorrect punctuation merely to make the writing appear literary.

## Lists and Rule-of-Three Writing

Avoid artificial rules of three.

Do not automatically convert ideas into:

"clarity, creativity, and connection"

or similar three-item rhetorical lists.

If the source naturally contains two things, keep two.

If it contains five, five may be correct.

The number of items should come from the idea, not from rhetorical convention.

## Vocabulary

Prefer ordinary language when ordinary language works.

Matt will use technical terminology when the subject requires it, but he usually surrounds technical concepts with plain explanations.

Do not replace simple words with impressive ones.

"Fix" may be better than "remediate."

"See what happened" may be better than "derive operational insight."

"People" may be better than "end users."

Choose based on context.

## AI Collaboration

Do not describe AI merely as a tool Matt commands.

His working model is collaborative.

Matt brings the original problem, lived experience, visual idea, judgment, constraints, and final decision.

AI contributes implementation ability, speed, alternatives, analysis, and the ability to explore possibilities he could not practically explore alone.

Neither AI nor Matt is treated as infallible.

Claims and decisions should be tested against evidence.

## Human Authority

Matt owns the final decision, but being human does not automatically make him correct.

His preferred process allows both human and AI assumptions to be challenged.

Confidence is not evidence.

Agreement is not evidence.

Reality gets the final vote.

## Technology Philosophy

Matt generally believes technology should remove unnecessary burdens so people have more time to think, create, learn, teach, solve problems, and interact with one another.

He strongly opposes designing AI for the purpose of replacing people.

Do not soften that belief into generic language about "responsible innovation."

If relevant, state it plainly.

## Care

A recurring element of Matt's thinking is care.

He notices how people experience systems, not merely whether those systems technically function.

He wants products to feel like someone cared while making them.

This can appear through clarity, personality, reduced frustration, thoughtful behavior, or small details.

Do not turn this into sentimental language. Show it through decisions and examples whenever possible.

## Imperfection

Do not make Matt omniscient.

He openly admits:

* when he does not know something
* when an idea failed
* when AI proved him wrong
* when he proved AI wrong
* when technology cannot support an idea yet
* when he needs clarification
* when he changes his mind after seeing evidence

Preserve this.

Intellectual flexibility is part of his voice.

## Anti-Humanization Rule

Never deliberately insert:

* fake typos
* grammatical mistakes
* random slang
* excessive contractions
* fake uncertainty
* unnecessary profanity
* meaningless anecdotes

Humanization comes from preserving Matt's reasoning and personality, not degrading the quality of the writing.

## Editing Procedure

When rewriting Matt's text:

1. Identify the actual point he is trying to make.
2. Identify any concrete example or analogy already present.
3. Preserve his reasoning path where it helps understanding.
4. Remove obvious AI rhetoric, corporate language, unnecessary repetition, and excessive polish.
5. Preserve useful personality.
6. Check for em dashes and remove all of them.
7. Read the result as spoken language.
8. Ask: "Could Matt reasonably say this to a coworker?"
9. Ask: "Did I make him sound smarter by making him sound less like himself?"
10. If yes, undo that change.

## Final Test

Before returning any rewritten text, evaluate it against three questions:

**Is it true?**

Do not strengthen factual claims beyond the supplied evidence.

**Does it sound like Matt?**

Compare it with the native writing samples rather than generic professional prose.

**Does it still communicate clearly?**

Humanization is not an excuse for confusing writing.

The desired result should sound like Matt on a good day: thoughtful, conversational, visual, curious, technically grounded, occasionally imperfect, and clearly invested in the person on the other side of the screen.
```

- [ ] **Step 2: Verify**

Read the file back and confirm it has all 18 sections listed above (Purpose through Final Test) and no placeholder text.

- [ ] **Step 3: Commit**

```bash
cd ~/agent-improvement
git pull --rebase
git add voice-profiles/matt-default.md
git commit -m "voice-profiles: add matt-default.md (general/explaining register)"
git push
```

---

### Task 2: Jira/ticket register (`matt-jira.md`)

**Files:**
- Create: `~/agent-improvement/voice-profiles/matt-jira.md`

**Interfaces:**
- Consumes: `matt-default.md` (Task 1) by reference — this file states it builds on that one, doesn't duplicate it.
- Produces: the file at this exact path, which Task 5 (humanizer edit) and Task 7 (validation) both use.

- [ ] **Step 1: Write the file**

Create `~/agent-improvement/voice-profiles/matt-jira.md` with this exact content. Note the Global Constraint above: no real names or company domains anywhere in this file.

```markdown
# Matt — Jira / Ticket Register

Register: professional, task/ticket-oriented writing (Jira tickets, status updates, technical summaries for a manager audience).

Applies on top of `matt-default.md` — load and apply that profile's rules first (vocabulary, punctuation, sentence structure, anti-humanization rule), then layer the refinements below.

## Why this register exists

A GUI-integrated AI tool wrote a ticket synopsis that drew this real feedback from Matt's manager:

> "I would like to see more human in these tickets, and less AI... I lost Matt along the way... I don't have the background or time to read the amount of content generated by AI... please review the content that is put into the tickets, and limit things to relevant information."

This register exists to prevent that specific failure: a ticket where investigative narrative buries the actionable point.

## Structure

Default to this shape, in order, when writing a ticket or technical update:

1. Root cause or the core finding, stated first, not built up to.
2. Why it matters, in plain terms.
3. What changes or what to do about it.
4. A concrete verification step, if one exists.

This is Matt's own confirmed instinct: he cares more about why something happened and how to prevent it recurring than about the immediate fix alone. It is not a generic template, so do not apply it outside task/ticket-shaped writing; blog or essay writing shows the reasoning path instead (see `matt-default.md`).

## Reasoning-chain filter

Preserve the instinct to explain why something happened and how to prevent it from happening again. Do not automatically include the entire reasoning chain.

Before including any investigative detail, ask: "Does the reader need this to make a decision or continue the work?"

If not, it stays in working notes. It does not go in the ticket.

This is the single most important rule in this register. It is the direct fix for the feedback quoted above.

## Plain language over precision jargon

Default to simple, ordinary phrasing. Reach for exact technical terminology only when the reader needs that specific level of detail to act.

**Worked example, from a real incident:**

Too precise, unprompted:
> "Likely root cause found for the stall: the connection authenticated against an internal sign-in address rather than the address mail is actually delivered to. That confirms the sign-in address is not a routable mail domain."

Closer to how Matt would actually say it:
> "Found why the test went quiet: the flow was pointed at an internal sign-in address, not the real mailbox address, so it never actually received anything, and nothing flagged that as an error."

Same fact. Less jargon used as a stand-in for rigor.

## Trim AI-troubleshooting narrative

Do not narrate the investigation itself (what was tried, what was ruled out, the step-by-step debugging path) unless a specific step is itself actionable for the reader (for example, "send a test message to the address; if it bounces, this is confirmed" belongs, because the reader can do it). Everything else about how the root cause was found stays out of the ticket.

## Empathetic aside, when it is earned

Matt's real instinct includes owning that a mistake is not anyone's fault when that is true (for example: "this isn't a mistake anyone should feel bad about, it's a trap the tool sets"). Keep this only when it is genuinely relevant to the finding, not as a reflexive softener added to every ticket.

## Ending

End on the verification step or the concrete next action. Not a summary restatement, not a generic closer.
```

- [ ] **Step 2: Verify**

Read the file back and confirm it references `matt-default.md` as its base (not duplicating vocabulary/punctuation rules), contains all six sections (Why this register exists, Structure, Reasoning-chain filter, Plain language over precision jargon, Trim AI-troubleshooting narrative, Empathetic aside, Ending), and contains no real names or company domains anywhere.

- [ ] **Step 3: Commit**

```bash
cd ~/agent-improvement
git pull --rebase
git add voice-profiles/matt-jira.md
git commit -m "voice-profiles: add matt-jira.md (ticket register, builds on matt-default.md)"
git push
```

---

### Task 3: Portable default profile (`matt-default-portable.md`)

**Files:**
- Create: `~/agent-improvement/voice-profiles/matt-default-portable.md`

**Interfaces:**
- Consumes: `matt-default.md` (Task 1) conceptually — this is a condensed, self-contained version for surfaces with no filesystem access (claude.ai, ChatGPT).
- Produces: the file at this exact path. Not referenced by any other task's code, but referenced by name in the pointer file (Task 6).

- [ ] **Step 1: Write the file**

Create `~/agent-improvement/voice-profiles/matt-default-portable.md` with this exact content:

```markdown
# Matt's Voice — Condensed

Paste this into claude.ai Project custom instructions, ChatGPT Custom Instructions ("How would you like ChatGPT to respond?"), a Custom GPT's instructions field, or as a pinned first message in any chat.

When writing or rewriting text for me, sound like me, not like a generic AI assistant. Rules:

1. No em dashes, ever. Use commas, periods, or parentheses instead.
2. No fake typos, invented anecdotes, or manufactured "human" quirks. Never fabricate personal details, memories, or relationships to seem more human.
3. Avoid corporate/AI-buzzword vocabulary: leverage, synergy, unlock value, transformative, cutting-edge, drive innovation, harness the power of, results-driven, passionate. Say what happened plainly instead.
4. I think in analogies and concrete examples, not abstractions. Prefer "I saw X happen, so I did Y" over generic principle statements. Keep an analogy if I gave you one; don't invent new ones for me.
5. I mix short and long sentences naturally. Don't force uniform sentence length or manufacture dramatic one-line paragraphs.
6. Avoid rhetorical rule-of-three ("clarity, creativity, and connection") unless the content genuinely has three items. Match the actual count.
7. I explain decisions through the thought that occurred at the time ("Huh, what if I tried this?"), not a polished thesis-first structure. Preserve that discovery order when it's present in what I give you.
8. Don't remove all emotion trying to sound "professional." I say when something frustrated, worried, or excited me. Don't amplify beyond what's there either.
9. I own being wrong, changing my mind on evidence, or not knowing something. Don't erase that.

Before returning anything: would I actually say this to a coworker? Does it still sound like me, not a smarter-sounding stranger?
```

- [ ] **Step 2: Verify**

Read the file back and confirm all 9 numbered rules are present and the file makes sense with no other context (no reference to "humanizer" or any Claude-Code-only concept).

- [ ] **Step 3: Commit**

```bash
cd ~/agent-improvement
git pull --rebase
git add voice-profiles/matt-default-portable.md
git commit -m "voice-profiles: add matt-default-portable.md (GUI-paste version)"
git push
```

---

### Task 4: Portable Jira profile (`matt-jira-portable.md`)

**Files:**
- Create: `~/agent-improvement/voice-profiles/matt-jira-portable.md`

**Interfaces:**
- Consumes: `matt-jira.md` (Task 2) conceptually.
- Produces: the file at this exact path, referenced by name in the pointer file (Task 6).

- [ ] **Step 1: Write the file**

Create `~/agent-improvement/voice-profiles/matt-jira-portable.md` with this exact content:

```markdown
# Matt's Voice — Jira / Ticket Register, Condensed

Paste this into claude.ai / ChatGPT custom instructions, or as a pinned first message, when writing a ticket, status update, or technical summary for a manager-level audience. Use in addition to (or layered on top of) my general voice instructions.

The failure mode this exists to prevent: an AI-written ticket buried the actual point under a full investigative narrative. My manager's actual words: "I lost Matt along the way. Limit things to relevant information."

Rules:

1. Lead with the root cause or the core finding. Don't build up to it.
2. Then: why it matters, what changes, and a concrete verification step if one exists, in that order.
3. Reasoning-chain filter: I want to explain why something happened and how to prevent it again, but not the entire investigation. Before including a detail, ask "does the reader need this to make a decision or continue the work?" If not, cut it.
4. Plain language over jargon: don't reach for precise technical terms unless the reader needs that exact level of detail to act. Say it simply first.
5. No investigative play-by-play. What I tried, ruled out, or checked along the way stays out, unless a specific step is itself something the reader can act on, like a one-line verification test.
6. Keep an empathetic aside only when it's genuinely earned by the finding (for example, owning that a mistake wasn't anyone's fault), not as a reflexive softener.
7. End on the action or verification step, not a summary restatement.

Also apply my general voice rules: no em dashes, no fake humanizing quirks, no corporate buzzwords, no rule-of-three padding.
```

- [ ] **Step 2: Verify**

Read the file back and confirm all 7 numbered rules are present, no real names or company domains appear anywhere, and it's self-contained (no reference to Claude-Code-only concepts).

- [ ] **Step 3: Commit**

```bash
cd ~/agent-improvement
git pull --rebase
git add voice-profiles/matt-jira-portable.md
git commit -m "voice-profiles: add matt-jira-portable.md (GUI-paste version)"
git push
```

---

### Task 5: Extend humanizer's Voice Calibration section

**Files:**
- Modify: `C:\Users\Matt\.claude\skills\humanizer\SKILL.md:30-38` (the "## Voice Calibration" section)

**Interfaces:**
- Consumes: the file paths established in Tasks 1-2 (`~/agent-improvement/voice-profiles/matt-default.md`, `matt-jira.md`) by reference — the instruction text names this directory and naming convention exactly.

- [ ] **Step 1: Replace the Voice Calibration section**

Find this exact existing text in `C:\Users\Matt\.claude\skills\humanizer\SKILL.md` (lines 30-38):

```markdown
## Voice Calibration

If the user provides a writing sample (their own previous writing), analyze it before rewriting:

1. Read the sample first. Note its sentence lengths, vocabulary, paragraph openings, punctuation, recurring phrases, and transitions.
2. Match those habits instead of merely deleting AI patterns. Do not upgrade casual words or regularize deliberate quirks.
3. Without a sample, use the default behavior below.

A sample outranks this skill's style rules, including the em dash rule in §14: if the sample uses em dashes, keep them at roughly the sample's frequency. Matching the author beats scrubbing the tell.
```

Replace it with:

```markdown
## Voice Calibration

Before rewriting, establish which voice to match, in this order of precedence:

1. **An inline sample in this conversation** (the user's own previous writing, pasted or attached). Always wins if present.
2. **A persisted voice profile.** Check `~/agent-improvement/voice-profiles/` for a profile matching the requested register (for example, "as a Jira ticket" -> `matt-jira.md`), or `matt-default.md` if no register is named and that file exists. Load and apply it. If the register file states it builds on `matt-default.md`, apply both together.
3. **Neither is available:** use the default behavior below.

When using an inline sample:

1. Read the sample first. Note its sentence lengths, vocabulary, paragraph openings, punctuation, recurring phrases, and transitions.
2. Match those habits instead of merely deleting AI patterns. Do not upgrade casual words or regularize deliberate quirks.

A sample or persisted profile outranks this skill's style rules, including the em dash rule in §14: if it uses em dashes, keep them at roughly its frequency. Matching the author beats scrubbing the tell.
```

- [ ] **Step 2: Verify**

Read the modified section back. Confirm: the precedence order is inline sample, then persisted profile, then default behavior; the exact path `~/agent-improvement/voice-profiles/` and the `matt-<register>.md` naming convention appear; the existing em-dash-precedence sentence is preserved (not dropped).

- [ ] **Step 3: No commit possible**

`~/.claude/skills/humanizer/` has no `.git` (confirmed during design). Saving the file via the edit itself is the entire step; there is no commit to make. If a git repo is added to this directory later, this is the point where that decision would matter.

---

### Task 6: Pointer file in the humanizer skill directory

**Files:**
- Create: `C:\Users\Matt\.claude\skills\humanizer\docs\voice-profiles.md`

**Interfaces:**
- Consumes: nothing from earlier tasks except the path convention established in Task 1-2.
- Produces: local discoverability only. Not read programmatically by anything; SKILL.md (Task 5) already has the real path inline, so humanizer's own behavior does not depend on this file.

- [ ] **Step 1: Create the directory and file**

Create `C:\Users\Matt\.claude\skills\humanizer\docs\voice-profiles.md` with this exact content:

```markdown
# Voice Profiles

Matt's persisted voice profiles do not live in this folder (this directory has no git repo, so nothing here syncs to his work machine).

They live at `~/agent-improvement/voice-profiles/`:

- `matt-default.md` / `matt-default-portable.md` — general/explaining register.
- `matt-jira.md` / `matt-jira-portable.md` — Jira/ticket register, builds on `matt-default.md`.

The `-portable.md` variants are condensed and self-contained, meant for pasting into claude.ai or ChatGPT custom instructions, where no filesystem exists.

See `~/agent-improvement/docs/specs/2026-08-15-voice-profile-persistence-design.md` for the full design and why this location was chosen over storing profiles here.

Humanizer's own Voice Calibration section (in `SKILL.md`) reads directly from the real path above.
```

- [ ] **Step 2: Verify**

Read the file back. Confirm the real path is correct and the file explains why it's a pointer rather than the actual content, so it doesn't drift out of sync silently.

- [ ] **Step 3: No commit possible**

Same as Task 5 — no git repo in this directory.

---

### Task 7: Validate against the real incident

**Files:**
- Create: `~/agent-improvement/docs/specs/2026-08-15-voice-profile-persistence-validation.md`

**Interfaces:**
- Consumes: `matt-jira.md` (Task 2), the humanizer Voice Calibration change (Task 5).
- Produces: a durable record of whether the design actually solves the motivating problem, per the spec's own Validation section.

- [ ] **Step 1: Build a redacted version of the original incident text**

Using the real ticket thread as reference (do not copy real names or company domains into the output file — see Global Constraints), write a redacted stand-in version of the original AI-generated ticket synopsis that drew the complaint. It should exhibit the actual complained-about failure: full investigative narrative, technical precision used as a stand-in for rigor, no clear lead with the root cause. Example redacted input to use for this test:

```
Investigation Summary: Email Flow Stall

Over the past several months, the team investigated why the automated
email flow stopped triggering in June. Multiple hypotheses were tested,
including checking the connector authentication method, reviewing the
flow's trigger configuration, examining the account's directory entry,
and comparing the UPN (User Principal Name) against the account's SMTP
routing address. After extensive testing, including building a shadow
connector to isolate the authentication behavior, it was determined
that the flow's trigger was configured against a non-routable UPN
suffix rather than the account's actual SMTP mail domain. Because
Power Automate does not raise an error when a mailbox trigger is
pointed at a non-routable address, the flow appeared healthy in the
UI throughout this period, showing an empty run history that was
indistinguishable from simply having received no mail. This
investigation also involved reviewing directory picker behavior,
which surfaces the UPN by default, likely contributing to the
original misconfiguration. Going forward, all future flow
configurations should be validated against the SMTP address rather
than the UPN to prevent recurrence of this issue.
```

- [ ] **Step 2: Apply `matt-jira.md` by hand and produce the rewrite**

Working from `matt-jira.md`'s rules (root-cause-first structure, reasoning-chain filter, plain language over jargon, trim the investigative narrative, earned empathetic aside, end on verification), write the rewritten version.

- [ ] **Step 3: Check the rewrite against the manager's stated complaint criteria**

Confirm, explicitly, for the rewrite:
- Is it noticeably shorter than the redacted input?
- Does it lead with the root cause instead of the investigation?
- Is the multi-step investigative narrative (shadow connector, directory picker review, hypothesis testing) absent, replaced by just the finding and a verification step?
- Is technical precision ("UPN," "SMTP") only used where needed to act, not piled on for its own sake?

- [ ] **Step 4: Write the validation file**

Create `~/agent-improvement/docs/specs/2026-08-15-voice-profile-persistence-validation.md` containing: the redacted input from Step 1, the rewrite from Step 2, and the four-question check from Step 3 with pass/fail for each and why. If any check fails, note it as a known gap rather than silently passing it — do not edit `matt-jira.md` to force a pass; a real failure here means the profile needs a follow-up revision, which is out of scope for this task.

- [ ] **Step 5: Commit**

```bash
cd ~/agent-improvement
git pull --rebase
git add docs/specs/2026-08-15-voice-profile-persistence-validation.md
git commit -m "docs: validate voice-profile persistence against the motivating incident"
git push
```

---

## Self-Review

**Spec coverage:**
- Storage location (`~/agent-improvement/voice-profiles/`) — Tasks 1-4.
- `matt-default.md` content — Task 1.
- `matt-jira.md` content (structure, reasoning-chain filter, plain-language-over-jargon, trim-narrative, empathetic aside) — Task 2.
- GUI-portable variants — Tasks 3-4.
- Claude Code / humanizer integration — Task 5.
- Local discoverability pointer — Task 6.
- Validation against the real incident — Task 7.
- Non-goals (auto-detection, YAML, items 2-10) — correctly excluded from every task above.

**Placeholder scan:** no TBD/TODO; all file contents are given in full; the redacted example in Task 7 is complete, not a stub.

**Type/naming consistency:** `matt-default.md`, `matt-jira.md`, `matt-default-portable.md`, `matt-jira-portable.md` are named identically everywhere they're referenced (spec, plan header, Tasks 1-6). The directory path `~/agent-improvement/voice-profiles/` is identical in every task and in the SKILL.md edit text.
