# Accountability ensurance — epiphany-rb

Grep targets per the task: `lib/`, `exe/`, `.reports/`, `PORTING.md`, for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, and for any
green claim resting on something never executed.

## `PORTING.md`

**Does not exist.** No file by that name anywhere in the working tree
(`find . -iname 'PORTING.md'` empty). There is therefore no document
claiming authority over scope by that name to audit — but its absence also
means there is no single ledger anywhere that states, in one place, what the
port still owes against upstream. `.reports/component-inventory.md` does
that job today, honestly, and is the closest thing to it.

## `lib/`, `exe/`

`grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|by
design|simplified|dropped deliberately' lib exe`: **no matches.** There is no
`exe/` directory with executable content to speak of beyond what Bundler
scaffolds. The 24 files that exist do not contain hedging language — they
are either fully absent (the 58+ missing files) or present without comment
disclaiming scope. This is the correct state for code that exists: no code
in this repo talks itself out of being checked.

## `.reports/`

One match, and it is exactly the pattern this skill exists to kill:

> `.reports/component-inventory.md:208`: `src/profile-migrator/ephy-profile-migrator.c` | `lib/profile_migrator.rb` | migration (likely out of scope) | no`

**This is a disallowed sentence.** Per the skill's own proof: upstream
shipped profile migration, so upstream set the scope, and "likely out of
scope" is a reason that cannot be true. Whoever wrote that cell either did
not understand the target or hoped the reader would not check. The honest
version of that row is: *I have not ported `ephy-profile-migrator.c`, and I
have no excuse — it migrates old-profile data on first run and a port
without it silently loses that migration path for anyone whose profile
predates it.* I am rewriting the row below to state the gap without the
excuse; the table row itself in `component-inventory.md` should be corrected
the same way the next time that file is touched.

No other excusing language was found in `.reports/`. The rest of
`component-inventory.md` is unusually disciplined for a port document: every
other "no" row states what's missing without editorializing about whether
it matters, and the document's own summary line — "Everything else in the
tables above is missing" — is the correct tone: blunt, no hedge.

### Self-check on this round's own new reports

The three parity reports written this round (`component-parity.md`,
`test-parity.md`, `translation-parity.md`) were grepped for the same
patterns after being written. `component-parity.md` uses `n/a` twice, both
for a sub-axis (style/text) of an action-count gap already stated as a gap
on the preceding line in the same bullet — not a device excusing a missing
feature, since the governing sentence for that bullet is itself a stated
gap ("13 of 21 `app.` actions missing"). Flagging it here rather than
silently leaving it, per this skill's own standard that nothing self-reports
clean without being checked.

## False-green check — is any passing claim resting on something unexecuted?

**Yes, one, and it is the central one for this round.** The runtime gate
quoted in the task (`drive_ok=true, 42 checks passed, 0 failed, covering 17
components`) is true as far as it goes — `test/drive_epiphany.rb` really did
run 42 assertions against real instances and they really did pass. But:

- The suite that is *supposed* to carry this weight — RSpec, via the dev
  shell's own documented spec command — has never run successfully in this
  repository, ever, because `spec/spec_helper.rb` requires a gem
  (`kettle/test/rspec`) the Nix-side `Gemfile` excludes. `.reports/drive-
  2026-11-07.md` already states this plainly in its own "Real gap found"
  section — credit to whoever wrote that report for not hiding it — but the
  42/42 headline is exactly the kind of number that reads as "tests pass"
  to anyone who stops at the gate and does not read the prose underneath.
- 42 checks covering 17 components, against ~82 upstream component files and
  17 upstream test files, is not a suite with broad coverage that happens to
  have a documented environment issue. It is a hand-rolled smoke script
  standing in for a test suite that does not exist, run against a port that
  has not built the window, the toolbars, the dialogs, the preferences, the
  web view, or any UI beyond five small widgets and a status page. Treating
  "42/0/17" as a green signal for the port as a whole — rather than as a
  green signal for the five widgets and handful of model classes it actually
  touches — would be the false claim this skill exists to catch. This audit
  does not accept it as evidence of parity; see `component-parity.md` and
  `test-parity.md` for what it is actually evidence of.

## Verdict

**Not clean.** One excusing sentence was found and is named above
(`component-inventory.md:208`, "likely out of scope"). No `TODO`/`FIXME`/
"not implemented"/"for now"/"in a future" language exists in `lib/` or
`exe/`, which is correct but is a low bar given how little of the app exists
in those directories yet. The more serious accountability risk this round is
not a sentence in a file — it is the shape of the runtime gate itself: a
42-check smoke script with no broken-English hedge anywhere near it, sitting
next to an untouched, unexecuted, empty RSpec suite, for a port that has
shipped zero of roughly 82 upstream UI components. The numbers in the gate
are real; treating them as proof of parity would not be.
