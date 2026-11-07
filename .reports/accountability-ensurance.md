# Accountability ensurance — epiphany-rb (this round)

Grep targets per the task: `lib/`, `exe/`, `.reports/`, `PORTING.md`, for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, and for any
green claim resting on something never executed.

## `PORTING.md`

Still does not exist (`find . -iname 'PORTING.md'` empty, re-checked this
round). No single ledger states, in one place, what the port still owes
against upstream; `.reports/component-inventory.md` remains the closest
thing to it.

## `lib/`, `exe/`

`grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|by
design|simplified|dropped deliberately' lib exe`: **no matches**, re-run
this round including the three new files
(`download.rb`/`downloads_manager.rb`/`mouse_gesture_controller.rb`). No
hedging language in code that exists.

## `.reports/` — the finding this round surfaced

**A number in this repo's own prior-round report was wrong, and it was wrong
in the direction of making the port look more complete than it is.**
`.reports/component-identification.md` (prior round) stated: "GActions
implemented: 8 (`app.` only)". Reading `lib/epiphany/application.rb` directly
this round: only two `Gio::SimpleAction`s are ever constructed —
`shortcuts_action` and `quit_action` — and only two accelerators are
registered. **The true count is 2, not 8.** This is not a hedge sentence
like "likely out of scope" (the pattern the prior round caught and fixed at
`component-inventory.md:208`); it is a factual overstatement that nobody
re-verified by reading the actual file before writing it down, and it would
have let this round's drive-script gate ("65 checks... covering 21
components") stand next to a claim that 8 app actions exist when 2 do. Fixed
in this round's `component-identification.md` and `component-parity.md`,
with the correction stated in both places rather than silently changing the
number.

The `component-inventory.md:208` row flagged last round
(`ephy-profile-migrator.c` | "migration (likely out of scope)" | no) was
**not corrected in the file itself** — re-checked this round, the row is
still there verbatim. The prior round's report said "the table row itself ...
should be corrected the same way the next time that file is touched," and
the file was touched this round (no — `component-inventory.md` was not
edited this round; only the identification/parity/test/translation reports
were). Flagging again: this is now the second round where a known-wrong
excusing sentence sits uncorrected in a committed report.

A second, smaller issue: the repo carries two committed drive reports with
overlapping, inconsistent content — `.reports/drive-2026-11-07.md` (stale,
42/42 from the prior round) and `.reports/epiphany-rb-drive-report.md`
(current, 65/65, matches this round's gate). Both are still present and
dated the same day. A reader who opens the first one sees a stale "42 of 42"
number next to a report named with today's exact date, which could be read
as the current result. Not a hedge, but a staleness/clarity gap worth
naming: the stale file should have been removed or clearly marked superseded
when the second one was written, and wasn't.

## False-green check — is any passing claim resting on something unexecuted?

Re-ran the two load-bearing executions myself this round rather than trusting
either report's prose:

- **Drive script**: `nix develop --command xvfb-run -a ruby
  test/drive_epiphany.rb` → **65 of 65 checks passed, DRIVE OK**, confirmed
  live. This number is real.
- **Spec command**: `nix develop --command ruby -e 'require "rspec/core";
  exit RSpec::Core::Runner.run([...])'` → `LoadError: cannot load such file
  -- kettle/test/rspec`, 0 examples, **exits 0**. Still broken, confirmed
  live, not carried forward on trust from the prior round's note.

The central false-green risk is unchanged in kind and now larger in scale:
65 checks across 21 named steps is a real, passing number, but it is
evidence for those 21 steps' code paths and nothing else. The task's own
runtime gate ("65 checks passed, 0 failed, covering 21 components") would
read as broad confirmation to anyone who stops at the gate — it covers 21
*of the port's own 26 files*, which is nearly all of what the port has built,
but that is a much smaller claim than "21 of the ~82 upstream component
files," and nothing in the gate text itself marks that distinction. Treating
"65/0/21" as evidence of parity with upstream Epiphany — rather than as
evidence that the ~5% of upstream chrome the port has actually built works
when driven directly — is exactly the false claim this skill exists to
catch, and it gets easier to make each round as the raw numbers grow while
the denominator (82 upstream component files, 0 window, 0 tabs, 0
preferences, 0 history, 0 passwords, 0 sync UI, 0 translations) does not
move.

## Verdict

**Not clean.** One factual overstatement was found and corrected this round
(`app.` action count, 8 claimed vs. 2 actual). One previously-flagged
excusing sentence (`component-inventory.md:208`, "likely out of scope")
remains uncorrected in the file a second round running, despite the prior
report saying it would be fixed "the next time that file is touched" — the
file simply wasn't touched, so the excuse is still sitting there. A stale,
inconsistent drive report (`drive-2026-11-07.md`, 42/42) sits alongside the
current one (`epiphany-rb-drive-report.md`, 65/65) with no note marking
either as superseded. And the structural risk from every prior round is
unchanged: a real, growing, honestly-run smoke-script gate (now 65/0/21) sits
next to a genuinely broken, silently-exit-0 RSpec path, for a port that has
shipped UI for zero of roughly 82 upstream component files, no translation
infrastructure for any of 110 languages, and a window that is still a status
page.
