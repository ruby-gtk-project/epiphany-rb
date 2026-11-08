# Translation parity — epiphany-rb vs upstream `origin/main`

Audit date: 2026-11-08, against `ruby` @ `2b13b416b`.

## Upstream

`po/POTFILES.in` lists 122 source files marked for extraction
(`data/org.gnome.Epiphany.desktop.in.in` through the `src/webextension/`
tree). Sampling two of them directly:

```
$ git show origin/main:src/ephy-window.c | grep -c '_("'
100
$ git show origin/main:src/window-commands.c | grep -c '_("'
65
```

165 marked strings from two files out of 122 — the full `.pot` (not checked
in; generated at build time) runs into the thousands across the whole
POTFILES list, and `po/LINGUAS` lists on the order of 100 shipped
translations. This is a fully-localized GNOME app.

## Port

```
$ grep -rc "gettext" lib/ exe/
(no output — zero matches in every file)
$ find . -iname "po" -maxdepth 2 | grep -v .git
(no output — no po/ directory)
```

There is no `po/` directory, no `.pot`, no `gettext`/`FastGettext`/`GLib
dgettext` call, and no `_()`/`N_()`-equivalent wrapper anywhere in `lib/` or
`exe/`. Every user-facing string the port has written is a bare Ruby string
literal. A sample from the files this round added, none of them translatable:

```
lib/action_bar_start.rb:   button.tooltip_text = 'Back'
lib/action_bar_start.rb:   button.tooltip_text = 'Forward'
lib/action_bar_start.rb:   button.tooltip_text = 'Reload'
lib/action_bar_end.rb:     button.tooltip_text = 'Bookmarks'
lib/action_bar_end.rb:     button.tooltip_text = 'Tab Overview'
lib/action_bar_end.rb:     button.tooltip_text = 'Downloads'
lib/page_menu_button.rb:   section.append('Run in Background', 'app.run-in-background')
lib/page_menu_button.rb:   section.append('New Window', 'app.new-window')
lib/page_menu_button.rb:   section.append('Quit', 'app.quit')
lib/window.rb:             button.tooltip_text = 'Exit Fullscreen'
```

This is consistent with every earlier file too (`shortcuts_dialog.rb`,
`notification.rb`, bookmarks/search-engine error messages, etc. — none of
them were gettext-wrapped before this round either, confirmed by the same
grep returning zero across the whole tree, not just the new files).

## Verdict

0 of the thousands of upstream `msgid`s survive, because there is no
mechanism by which any of them *could* survive: the port has not adopted
gettext (or any i18n library) at all. This is not "some strings missed
translation" — it is a totally untranslated, English-only application, and
nothing in `lib/`, `exe/`, the gemspec, or the Gemfile takes a dependency
that would make translation possible (no `gettext`, `fast_gettext`,
`r18n`, or similar gem is declared). `LINGUAS`'s ~100 shipped locales all
regress to English in this port, for every string, with no partial credit:
there is no locale in which this app currently shows anything other than
the English literals above.

The previous `.reports/translation-parity.md` from this repository's
history already reached the same conclusion before this round's window/
header-bar/action-bar port landed; this pass re-confirms it is still true
after nine more files' worth of new, still-unwrapped, still-English
strings were added on top.
