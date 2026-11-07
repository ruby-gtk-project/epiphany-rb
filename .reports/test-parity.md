# Test parity — epiphany-rb vs origin/main

## Upstream census (unchanged from base round)

`tests/*-test.c` on `origin/main` — 17 test files (18th, `ephy-test-utils.c`,
is shared helper code, not a suite):

`ephy-download-test.c`, `ephy-embed-shell-test.c`, `ephy-embed-utils-test.c`,
`ephy-encodings-test.c`, `ephy-file-helpers-test.c`, `ephy-history-test.c`,
`ephy-location-entry-test.c`, `ephy-migration-test.c`,
`ephy-search-engine-manager-test.c`, `ephy-session-test.c`,
`ephy-shell-test.c`, `ephy-snapshot-service-test.c`, `ephy-sqlite-test.c`,
`ephy-string-test.c`, `ephy-uri-helpers-test.c`, `ephy-web-extension-test.c`,
`ephy-web-view-test.c`.

Note `ephy-download-test.c` exists upstream and now has a plausible port-side
home (`lib/download.rb`, added this round) — flagged below.

## Port side — re-verified this round

- `find spec -type f`: still only `spec/spec_helper.rb`, `spec/README.md`.
  **Zero spec files**, unchanged.
- `test/drive_epiphany.rb` grew from 42 to 65 checks across 21 named steps
  this round, adding coverage for `Download`/`DownloadsManager` and
  `MouseGestureController`. Ran it directly this round:
  `nix develop --command xvfb-run -a ruby test/drive_epiphany.rb` →
  **65 of 65 checks passed, DRIVE OK**, confirmed live, not taken on faith.
- None of the 65 checks is named after, or derived case-by-case from, an
  upstream `tests/*-test.c` function. They remain a hand-rolled smoke
  script, now larger, still not a port of the upstream suite.

## Bijection check

- Upstream: 17 test files.
- Port test count mapped to an upstream test by name: **0**, unchanged.
- `ephy-download-test.c` now has a plausible port-side home
  (`lib/download.rb`/`lib/downloads_manager.rb` both exist and are touched
  by the drive script) but still has no named spec ported from it — same
  pattern as `ephy-encodings-test.c` and
  `ephy-search-engine-manager-test.c` noted in the base round.
- `ephy-location-entry-test.c`, `ephy-history-test.c`, `ephy-session-test.c`,
  `ephy-web-view-test.c`, `ephy-shell-test.c` still test subsystems that do
  not exist in the port (`location_entry.rb`, `history_dialog.rb`/
  `history_service.rb`, `session.rb`, `web_view.rb`, the full shell action
  set), so there is still nothing to port those tests against.

## Does the suite actually run?

**Still no — re-confirmed directly this round, not assumed from the prior
report.** Ran the dev shell's documented spec command myself:

```
nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Result: `LoadError: cannot load such file -- kettle/test/rspec`, raised from
`spec/spec_helper.rb:23`. The run then reports "0 examples, 0 failures, 2
errors occurred outside of examples" and **exits 0** — which is itself worth
flagging: a broken spec load that exits zero reads as "passed, nothing to
do" to any automation that checks only the exit code, when what actually
happened is the suite never loaded. Nothing in this round's code changed
this; it is the same pre-existing packaging gap the base round found
(`kettle-test`/`kettle-dev` unresolved in the offline Nix environment), still
unfixed, re-verified live rather than carried forward on trust.

## Runtime gate cross-check

This round's gate: "65 checks passed, 0 failed, covering 21 components" —
verified true by running it. Per the task's framing, a component no check
exercises is unverified, not done, and the inverse holds too: these 65
checks prove `test/drive_epiphany.rb`'s 21 steps work when invoked
in-process; they do not constitute test parity with the 17 upstream test
files, because none of the 65 is a named port of an upstream case. The gate
passing is real and is evidence for exactly the 21 components it names — not
for the ~61 upstream component files (82 total minus 21 this round's drive
touches) it does not touch, and not for the 17 upstream test files, 0 of
which have a counterpart.

## Verdict

**Gap, total — 17 of 17 upstream test files unported (0 bijection) — plus a
second, independent gap: the one RSpec execution path the project documents
is broken, confirmed broken again this round by actually running it, not
by re-reading last round's note.** `test/drive_epiphany.rb` is larger and
still honestly labeled, still exercises real instances, and still is not the
test suite, was not built from the upstream census, and does not close this
gap. The exit-code-0-on-load-failure behavior of the broken spec command is
a second-order risk worth calling out on its own: any CI step that checks
only "did the spec command exit nonzero" would currently call this a pass.
