# Accountability ensurance — epiphany-rb

Audit date: 2026-11-08, against `ruby` @ `2b13b416b`. Grepped `lib/`, `exe/`,
`.reports/`, and checked for `PORTING.md` (absent — there is no such file in
this repo; nothing to grep there).

## Grep results

```
$ grep -rniE "TODO|FIXME|not implemented|for now|in a future|unimplemented" lib/ exe/
(no matches)
```

No literal `TODO`/`FIXME`/"not implemented" markers exist in the code. That
is not the same as nothing being excused — see below, where the excusing is
done in full sentences instead of a marker, and is in most cases honestly
labeled. The one place this audit treats as a genuine violation is the
**runtime-verification gap**, not the scoping language.

## Where gaps are candidly stated (not a violation, but logged)

Every file this round touched says what it left out, in its own header
comment, and the omissions check out against the codebase on direct
reading:

- `lib/window.rb:17-23` — "upstream's window holds one EphyEmbed per tab and
  drives navigation, zoom and find through WebKitWebView; that layer
  (ephy-embed.c) is not in this round's component list and is not ported... there is just no actual network fetch or page render behind the addresses."
- `lib/header_bar.rb:18-19` — "this round has no editable LocationEntry yet
  (not ported), so the header bar always shows the read-only TitleBox."
- `lib/tab_view.rb:13-18` — placeholder content per tab, explicitly labeled.
- `lib/action_bar_start.rb:11-15` — no history popover, explicitly labeled.
- `lib/action_bar_end.rb:17-19` — no browser-action popover for web
  extensions, explicitly labeled.
- `lib/page_menu_button.rb:11-14` — pruning rationale given.

These are honest disclosures, not the kind of buried "for now" the task
asks to catch. The problem is what sits on top of them.

## The real finding: "this round's component list" is self-declared, not externally set

There is no `PLAN.md`, `ROADMAP.md`, or any committed document in this repo
that defines what "this round" is scoped to (`find . -iname 'PLAN.md' -o
-iname 'ROADMAP.md'` → nothing; `grep -rln 'component list' . --include
'*.md'` only matches a skill file under `.claude/skills/`, not a port-scope
document). The phrase "this round's component list" in `window.rb`'s own
comment is therefore the porting agent's own retrospective justification for
what it chose to skip, written into the same commit that does the skipping.
That is a self-graded scope cut, not a tracked, reviewable decision — and it
is exactly the shape of thing this skill exists to catch even when the words
used are honest rather than evasive. Flagging it here so the next round
either produces a real plan document or stops narrating scope decisions
inside the commits that make them.

## The most serious finding: a report claimed a drive run verified things it never touched

`.reports/epiphany-rb-drive-report.md` (and the round's own commit message
for `2b13b416b`) describe the drive script as updated "to exercise the new
window (tabs, navigation, action-triggered tab add/close...)". Re-running
the drive script for this audit confirms **80 of 80 checks pass** — that
number is real, reproduced, not fabricated. But reading `test/drive_epiphany.rb`
line by line (see `component-parity.md` for the full account) shows the
"window" step only checks: window exists, title, one initial tab, the page
menu button's existence and item count, tab add/jump/navigate/close via
direct method calls on the `Window` object, and chrome-visibility toggling.
It never:

- drives the `toolbar.navigation-back`/`-forward` **actions** (the actual
  click path), which is how this audit found they are permanently
  `enabled = false` and never re-enabled — a real, user-visible dead button
  that 80/80 green checks do not surface, because no check invokes the
  action a button click would invoke, only the underlying model method.
- opens either downloads `Gtk::MenuButton`, which is how this audit found
  neither has a `.popover` set.
- activates any of the 8 page-menu items whose action is never installed.
- touches `ActionHelper`, `TabView#attach_tab_bar`, or the bookmarks toggle's
  actual effect.

None of this is a false statement in the commit message or the drive
report — "80 of 80 checks pass" is literally true, and "exercise the new
window" is literally true of the subset it does touch. But the overall
effect, read by anyone who treats "drive run passed" as "the window is
verified," is a false green: a narrow, passing run standing in for coverage
it does not have. The task's framing — "a component no check exercises is
unverified, not done" — is doing real work here: by that standard, the
back/forward buttons, both downloads popovers, 8 of 13 menu items, and the
tab bar are **unverified**, full stop, regardless of the 80/80 topline.

## The test-suite false-green risk, specifically

See `test-parity.md` for the full account: `rake spec`/`rspec` never
successfully loads on this branch (`cannot load such file -- kettle/test/rspec`),
and exits 1 with "0 examples, 0 failures" printed. The exit code is correct
and would fail a real CI gate, but "0 examples, 0 failures" is text that
reads as green to anyone scanning for failure counts rather than the error
block above it. This audit ran the exact command the dev shell prints and
is the first artifact in this repository's history to record that it fails
— no `.reports/*.md` before this one states that the RSpec suite was ever
actually executed. Treat every prior green claim about "test coverage" in
this repo's history as resting on the drive script alone, never on RSpec,
because RSpec could not run.

## Summary table

| Claim | Status |
|---|---|
| "80 of 80 checks pass" (this round, reproduced) | True, but covers a fraction of what was shipped — see above |
| "drive_ok=true... covering 35 components" (task's runtime gate) | True as a count; narrow as a coverage claim — many of the 35 are touched by 1-2 checks that don't reach their action/signal wiring |
| Browsing (WebKit embed) not ported | Disclosed honestly in commit message and code comments |
| LocationEntry/address bar not ported | Disclosed honestly |
| Test suite "ported" | **Never true** — 0 of 18 upstream test files exist on this branch, and the port's own RSpec harness has never successfully run |
| Translations | **Never true** — zero gettext infrastructure, zero `po/`, confirmed by grep |
| Self-declared scope ("this round's component list") | Not externally tracked; the porting agent is grading its own cut |
