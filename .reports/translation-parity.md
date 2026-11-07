# Translation parity — epiphany-rb vs origin/main

## Upstream catalogue (unchanged, re-confirmed)

- `po/LINGUAS`: 110 languages — re-confirmed this round with
  `git show origin/main:po/LINGUAS | tr ' ' '\n' | grep -c .` type counting
  against the file directly.
- `po/POTFILES.in` begins with `data/org.gnome.Epiphany.desktop.in.in`,
  `data/org.gnome.epiphany.gschema.xml`,
  `data/org.gnome.Epiphany.metainfo.xml.in.in` (re-read directly this round)
  and runs to 117 source files total per the existing component inventory.

## Port side — re-verified this round, including the two new files

- `grep -rn "gettext\|N_(\|_(\"" lib exe`: **zero matches** across the whole
  tree, including `lib/download.rb`, `lib/downloads_manager.rb`, and
  `lib/mouse_gesture_controller.rb` added this round — none of the three
  introduces a user-visible string at all (they are model/controller code
  with no label, title, or tooltip text), so this round neither closes nor
  widens the translation gap; it simply doesn't touch it.
- `find . -iname '*.po' -o -iname '*.pot'` (excluding `.git`): still empty.
  No `po/` directory, no `LINGUAS`, nothing.
- No gettext-family gem anywhere in `Gemfile`/`epiphany-rb.gemspec`.
- The strings that do exist and are user-visible — `lib/epiphany/application.rb`'s
  `status_page` description ("Ported so far: settings, bookmarks..."),
  `page_menu`'s `"Keyboard Shortcuts"`/`"Quit"`, `menu_button`'s
  `"Main Menu"` tooltip — are all plain Ruby string literals with no msgid,
  same as every prior round.

## Three-claim check

1. **Key sets equal.** Upstream: N keys across 117 files. Port: **0**,
   unchanged.
2. **Byte-identical keys.** Vacuous, unchanged.
3. **Languages ship.** 0 of 110, unchanged.

## Verdict

**Gap, total, unchanged by this round.** The port still ships zero
translation infrastructure: no marked strings anywhere in `lib/` (including
the three new files), no gettext dependency, no `po/` directory, no
catalogue, no build step, no installed language. All 110 languages upstream
ships are silently dropped. This is not "English-only for now" — per the
`accountability-ensurance` framing that phrase excuses rather than states
the gap — it is zero infrastructure, confirmed again by direct grep this
round rather than carried forward from the prior report.
