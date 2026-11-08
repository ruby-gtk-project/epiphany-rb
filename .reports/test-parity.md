# Test parity — epiphany-rb vs upstream `origin/main`

Audit date: 2026-11-08, against `ruby` @ `2b13b416b`.

## Upstream test suite

`git ls-tree -r --name-only origin/main | grep -i test` lists 18 test
sources under `tests/`, meson-driven (`tests/meson.build`):

```
ephy-download-test.c            ephy-location-entry-test.c
ephy-embed-shell-test.c         ephy-migration-test.c
ephy-embed-utils-test.c         ephy-search-engine-manager-test.c
ephy-encodings-test.c           ephy-session-test.c
ephy-file-helpers-test.c        ephy-shell-test.c
ephy-history-test.c             ephy-snapshot-service-test.c
                                 ephy-sqlite-test.c
                                 ephy-string-test.c
                                 ephy-uri-helpers-test.c
                                 ephy-web-extension-test.c
                                 ephy-web-view-test.c
```
(plus `ephy-test-utils.c`/`.h`, shared fixtures, not a test file itself)

## Port side: zero of these are ported

```
$ ls spec/
README.md  spec_helper.rb
```

There is no `*_spec.rb` anywhere in the repository. `spec/README.md`
describes the harness (`kettle-test`); `spec/spec_helper.rb` configures
SimpleCov and RSpec. Neither is a test. **0 of 18 upstream test files have
any counterpart.** None of the encodings, search-engine-manager, history,
download, or string/uri-helper behavior the port has reimplemented in
`lib/encodings.rb`, `lib/search_engine_manager.rb`, `lib/download.rb`, etc.
has a corresponding RSpec example — the only verification any of that code
gets is the hand-rolled `test/drive_epiphany.rb` script, which is not RSpec
and is not what `rake spec` runs.

## The suite that exists does not run

This is not a hypothetical — it was executed for this audit, using the exact
invocation the dev shell's own banner prints:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
Failure/Error: require "kettle/test/rspec"
LoadError:
  cannot load such file -- kettle/test/rspec
# ./spec/spec_helper.rb:23:in '<top (required)>'
No examples found.
Finished in 0.00005 seconds (files took 0.19473 seconds to load)
0 examples, 0 failures, 2 errors occurred outside of examples
$ echo $?
1
```

`kettle-test` is declared in `epiphany-rb.gemspec` as a development
dependency (`spec.add_development_dependency("kettle-test", "~> 2.0", ">=
2.0.29")`, line 140) but is not resolvable in the project's own Nix dev
shell — `spec_helper.rb` cannot even load. The process does exit non-zero
(1), so a CI gate checking exit status would correctly fail this; but the
"0 examples, 0 failures" line is exactly the shape of text a less careful
check (or a human skimming output) reads as green. **This suite has never
been run successfully on this branch.** Before this audit, nothing in
`.reports/` recorded that it had been tried — the existing `test-parity.md`
(dated before this pass) made claims about test coverage without the
command above ever having been executed and its failure recorded.

## What "driven" actually means here

`test/drive_epiphany.rb` (80 checks, reported passing — reproduced in this
audit, see `component-parity.md`/the runtime gate) is a real, working
integration script, but it is not a test suite in any sense that gives
upstream-file-by-upstream-file parity:

- It has no file-to-file correspondence with `tests/*.c` — it is one script
  covering whatever the port currently has, not 18 units mapped to 18
  upstream units.
- It is not run by `rake spec`, is not RSpec, is not discovered by any CI
  task name this repo defines (`grep -n spec Rakefile` shows the `kettle-dev`
  generated `rake spec` task, which points at `spec/`, not `test/`).
- Its own `.reports/epiphany-rb-drive-report.md` is explicit that it only
  drives "every component this round of the port landed" — by construction
  it cannot catch a regression in anything not yet ported, and (see
  `component-parity.md`) it does not even exercise everything that *is*
  ported in the latest commit (the dead back/forward actions, the
  popover-less downloads buttons, and 8 of 13 page-menu items are none of
  them touched by any check).

## Gap summary

| Upstream test file | Ported? | Port-side equivalent |
|---|---|---|
| ephy-encodings-test.c | ❌ | drive script step only |
| ephy-search-engine-manager-test.c | ❌ | drive script step only |
| ephy-download-test.c | ❌ | drive script step only |
| ephy-history-test.c | ❌ | none (no history service ported) |
| ephy-string-test.c | ❌ | none |
| ephy-uri-helpers-test.c | ❌ | none |
| ephy-file-helpers-test.c | ❌ | none |
| ephy-location-entry-test.c | ❌ | none (LocationEntry not ported) |
| ephy-session-test.c | ❌ | none (Session not ported) |
| ephy-sqlite-test.c | ❌ | none |
| ephy-migration-test.c | ❌ | none |
| ephy-shell-test.c | ❌ | none |
| ephy-embed-shell-test.c | ❌ | none |
| ephy-embed-utils-test.c | ❌ | none |
| ephy-snapshot-service-test.c | ❌ | none |
| ephy-web-extension-test.c | ❌ | none (no web-extension layer ported) |
| ephy-web-view-test.c | ❌ | none (no embed layer ported) |

18 of 18 upstream test files: not ported. The port's own test infrastructure
(`spec/`) does not execute. Say this plainly, as instructed: this is a
suite that has never been run, not a suite with gaps.
