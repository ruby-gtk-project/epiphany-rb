# Component identification — epiphany-rb vs origin/main (round: downloads + mouse gestures)

Updates `.reports/component-inventory.md` (the base census, still correct in
its method and still the right place to look for the full table) for what
changed this round: `lib/download.rb`, `lib/downloads_manager.rb`, and
`lib/mouse_gesture_controller.rb` were added, and `test/drive_epiphany.rb`
grew from 42 to 65 checks across 21 named steps.

## Method

- `git ls-tree -r --name-only origin/main` walked again for `src/`, `embed/`,
  upstream `lib/`, `data/`, `po/` — unchanged from the base census (163
  `src/*.c`+`*.h`+`.blp` files alone; the full upstream UI surface is larger
  once `embed/` and `.blp` templates outside `src/` are counted).
- Port side: `find lib exe -name '*.rb'` → 26 files today (23 at the base
  census + the 3 added this round).
- Verified the actual action count in `lib/epiphany/application.rb` by
  reading the file directly, rather than trusting the prior report's number.

## Correction to the prior round's report

The base `component-identification.md` stated "GActions implemented: 8
(`app.` only)". **That number is wrong.** Reading
`lib/epiphany/application.rb` directly: only two `Gio::SimpleAction`s are
ever constructed and added — `shortcuts_action` and `quit_action`
(`app.add_action(shortcuts_action)` / `app.add_action(quit_action)`, lines
62–63). The `ACCELERATORS` hash also only has two entries. There are no other
`SimpleAction.new` calls anywhere in the file. **The true count is 2 of 21
upstream `app.` actions, not 8.** This is flagged again in
`accountability-ensurance.md` since it is a report overstating what the port
has built, which is exactly the kind of false-green claim that skill exists
to catch.

## What this round added (confirmed by reading the files)

| File | Upstream | Ported surface |
|---|---|---|
| `lib/download.rb` | `embed/ephy-download.c` | `Download` model: uid counter, action enum (none/browse_to/open), wraps a caller-supplied WebKit-download-shaped object |
| `lib/downloads_manager.rb` | `embed/ephy-downloads-manager.c` (or equivalent) | `DownloadsManager`: in-process download list |
| `lib/mouse_gesture_controller.rb` | `src/ephy-mouse-gesture-controller.c` | middle-button drag gesture → win/toolbar/tab action activation, single- and two-stroke sequences |

All three carry the upstream-file-naming comment the house style requires,
and all three are exercised by `test/drive_epiphany.rb` (confirmed by running
the drive script — see `.reports/epiphany-rb-drive-report.md`).

None of the three builds any widget chrome. `download.rb` has no
`download_widget.rb`/`downloads_popover.rb`/`downloads_paintable.rb`
counterpart (still 0 of those 3 files); `mouse_gesture_controller.rb` is
attached to a `window_adapter` struct standing in for the real window, since
`lib/window.rb` still does not exist.

## Updated port component count

| Facet | Count | Source |
|---|---:|---|
| `lib/*.rb` + `exe/*` files | 26 | `find lib exe -name '*.rb'` |
| `app.` GActions implemented | **2** (`shortcuts`, `quit`) — not 8 as the prior report said | read `lib/epiphany/application.rb` directly |
| `win.`/`toolbar.`/`tab.`/`popup.` GActions implemented | 0 (the four `Gio::SimpleActionGroup`s in `window_action_groups` are created empty — placeholders for a window that doesn't exist yet) | same |
| Keyboard accelerators wired | 2 | `ACCELERATORS` hash |
| GSettings keys | 103 (claimed ported in full, unchanged) | `lib/settings.rb` |
| `spec/*_spec.rb` | 0 (unchanged) | `find spec -type f` |
| Drive-script checks | 65 (up from 42), across 21 named steps (up from 17) | ran `test/drive_epiphany.rb` directly this round — passes, confirmed |

## Verdict on this axis

Still true from the base round: of ~82 distinct upstream component files (37
`.blp` + ~45 code-built), the port has built the chrome for **zero** of
them. This round's three new files are all model/controller layer with no
widget tree of their own, consistent with every prior round. The identified
census remains honest about what's missing; the one number that needed
correcting (`app.` action count) is corrected above.
