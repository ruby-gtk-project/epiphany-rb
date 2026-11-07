# Translation parity — epiphany-rb vs origin/main

## Upstream catalogue

- `po/LINGUAS`: 110 languages (confirmed: `git show origin/main:po/LINGUAS`
  lists 110 codes, from `ab` to `zh_HK`/`zh_TW`).
- `po/POTFILES.in`: 117 source files feed the message catalogue, per the
  existing component inventory (`.reports/component-inventory.md`).
- Message count: not independently re-extracted for this report (no `xgettext`
  available in the ambient shell and the task scopes this audit to the `ruby`
  branch's working tree, which never checks out `origin/main`), but the scale
  — 110 languages, 117 source files — is itself the material fact: this is
  the largest body of donated translation work in the upstream repository,
  per the skill's own framing, and none of it currently has anywhere to land
  in the port.

## Port side

- `grep -rn '_(' lib`: **zero matches.** No string in `lib/*.rb` is wrapped in
  a gettext call or any translation marker.
- `grep -rn gettext Gemfile* lib`: **zero matches.** No gettext gem
  (`gettext`, `fast_gettext`, `ruby_gettext`, or similar) is declared as a
  dependency anywhere in `Gemfile`/`Gemfile.lock`/`gemset.nix`.
- No `po/` directory exists under the port root. No `.pot`, no `.po`, no
  `.mo`, no `LINGUAS` file. `find . -iname '*.po' -o -iname '*.pot'` (run
  against the `epiphany-rb` working tree) returns nothing.
- The existing component inventory already records this plainly:
  "Translations | `po/` 110 LINGUAS, `po/POTFILES.in` 117 source files |
  not wired."

## Three-claim check

1. **Key sets equal.** Upstream: N keys across 117 files. Port: **0** keys,
   because nothing is marked. Not equal by any measure.
2. **Byte-identical keys.** Vacuous — there are no port-side keys to compare.
   Every user-visible string the port does show (notification text, floating
   bar labels, shortcuts-dialog item text, status-page text) is a plain Ruby
   string literal with no msgid, so even if a catalogue were built today it
   would not line up with upstream's wording unless every one of those
   literals happened to already match upstream's C strings byte for byte —
   unverified and, per the skill's own warning, not something to assume.
3. **Languages ship.** 0 of 110. There is no `.mo` build step, no
   `LINGUAS` file, nothing in `Rakefile` or the Nix flake that installs or
   loads a translation catalogue for the app.

## Verdict

**Gap, total.** This is not "English-only for now" — per the
`accountability-ensurance` framing, that phrase is itself a disallowed way of
writing this finding down. The port ships zero translation infrastructure:
no marked strings, no gettext dependency, no `po/` directory, no catalogue,
no build step, no installed language. All 110 languages upstream ships are
silently dropped. This is unrelated to and does not improve with the UI
build-out tracked in `component-parity.md` — even the handful of widgets
that do exist today (`notification.rb`, `floating_bar.rb`,
`shortcuts_dialog.rb`, the status page in `epiphany/application.rb`) show
unmarked, untranslated strings.
