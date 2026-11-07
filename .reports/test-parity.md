# Test parity — epiphany-rb vs origin/main

## Upstream census

`tests/*-test.c` on `origin/main` (confirmed via `git ls-tree -r --name-only
origin/main | grep '^tests/'`):

1. `ephy-download-test.c`
2. `ephy-embed-shell-test.c`
3. `ephy-embed-utils-test.c`
4. `ephy-encodings-test.c`
5. `ephy-file-helpers-test.c`
6. `ephy-history-test.c`
7. `ephy-location-entry-test.c`
8. `ephy-migration-test.c`
9. `ephy-search-engine-manager-test.c`
10. `ephy-session-test.c`
11. `ephy-shell-test.c`
12. `ephy-snapshot-service-test.c`
13. `ephy-sqlite-test.c`
14. `ephy-string-test.c`
15. `ephy-test-utils.c` (helper, not a test file itself)
16. `ephy-uri-helpers-test.c`
17. `ephy-web-extension-test.c`
18. `ephy-web-view-test.c`

That is 17 upstream test *files* (18th is shared test-utility code, not a
suite of its own), each containing multiple `g_test_add_func` cases — the
skill asks for a test-by-test census, not file-by-file, but file count alone
already settles the question below.

## Port side

`find spec -type f`: `spec/spec_helper.rb`, `spec/README.md`. **Zero spec
files.** `grep -rn 'it ' spec` / `grep -rn 'describe' spec`: nothing, because
there is nothing to grep.

The only executable check in the repository is `test/drive_epiphany.rb` (298
lines) plus `test/gtk_driver.rb` (214 lines) — a hand-rolled smoke-test
script, not an RSpec/Minitest suite, and not mapped file-by-file or
case-by-case to any upstream test. It asserts 42 ad hoc checks across 17
components it chose to exercise (bookmarks add/find/tag/remove, search-engine
default-load/custom-add/bang-parsing, permissions set/get, encodings
load/lookup, sync hex/base64, link modifier mapping, suggestion state,
notification show/dedupe/hide, floating-bar label, search-entry match
counter, title-widget contract, shortcuts-dialog open, app.quit geometry
save). None of these checks were derived from, or named after, an upstream
`tests/*-test.c` case — they were written from scratch to fit whatever the
port currently has.

## Bijection check

- Upstream test count: 17 files, dozens of individual `g_test_add_func`
  cases inside them (not enumerated case-by-case here, but immaterial — the
  file-level count alone fails).
- Port test count mapped to an upstream test by name: **0.**
- Every one of the 17 upstream test files is a gap. None has a named Ruby
  counterpart. `ephy-location-entry-test.c`, `ephy-history-test.c`,
  `ephy-session-test.c`, `ephy-web-view-test.c`, `ephy-shell-test.c` test
  subsystems (`location_entry.rb`, `history_dialog.rb`/`history_service.rb`,
  `session.rb`, `web_view.rb`, the full shell actions) that do not exist in
  the port yet, so there is nothing to even begin porting those tests
  against.
- `ephy-encodings-test.c`, `ephy-search-engine-manager-test.c`: have a
  plausible port-side home (`lib/encodings.rb`, `lib/search_engine_manager.rb`
  both exist and are touched by the drive script) but still have **no named
  spec** — the drive script's ad hoc assertions are not a substitute; they
  were not written against the upstream test's cases, they were written
  against whatever the port author decided to check this round.

## Does the suite actually run?

**No, and this is a gap in its own right, separate from the missing
content.** `.reports/drive-2026-11-07.md` records it directly: the dev
shell's own documented spec command —

```
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

— fails to load, because `spec/spec_helper.rb` requires `kettle/test/rspec`,
which the Nix-side `Gemfile` does not provide. The banner the dev shell
prints names this as *the* way to run tests, and it does not work. There is
no evidence in this repository that RSpec has ever successfully executed
here — not once, for any example, because there are also no examples to run.
A suite that has never been executed, with zero content, is a gap on two
axes at once: it isn't ported, and the one command that would run it if it
were ported is broken.

The only thing that does run is `test/drive_epiphany.rb`, via
`nix develop --command xvfb-run -a ruby test/drive_epiphany.rb`, and it is a
standalone script outside the RSpec/Minitest harness the project otherwise
sets up — it is not what `rake spec` or the dev-shell's spec command invokes.

## Runtime gate cross-check

This round's gate reports "42 checks passed, 0 failed, covering 17
components." Per the task's framing, a component no check exercises is
unverified, not done — and the inverse also holds here: a check that is not
a named port of an upstream test is evidence the *script* works, not evidence
of test *parity*. The 42-check pass is real and does show those 17
components' code paths doing something when invoked directly in-process,
but it answers a different question than the one this skill asks (is every
upstream test ported and run), and it is not a substitute for that answer.

## Verdict

**Gap, total — 17 of 17 upstream test files unported (0 bijection), and the
one test-execution path the port does have (RSpec via the dev shell) is
documented as broken, not merely empty.** `test/drive_epiphany.rb` is a
useful, honestly-labeled smoke script, but it is not the test suite, was not
built from the upstream census, and does not close this gap.
