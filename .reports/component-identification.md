# Component identification — epiphany-rb vs origin/main

This report is the per-file component census the `component-identification`
skill asks for. It does not re-derive the full inventory from scratch — that
census already exists at `.reports/component-inventory.md`, built the same
way this skill prescribes (blueprints first, then the C files, mapped file by
file to the `ruby`-branch target). This report checks that census against the
tree and adds counts the skill requires that the existing document left
implicit.

## Method

- `git ls-tree -r --name-only origin/main` (688 files) walked for `src/`,
  `embed/`, `lib/` (upstream C `lib/`, not the port's), `data/`, `po/`.
- `.blp` files read for widget trees; `.c` files read for code-built widgets,
  actions and signal connections.
- Port side: all 24 files under `epiphany-rb/lib/`.

## Upstream component count (confirmed against the tree)

| Facet | Count | Source |
|---|---:|---|
| `.blp` template files | 37 | `src/resources/gtk/*.blp` |
| Component-bearing `.c`/`.h` pairs outside `.blp` coverage | ~45 | `ephy-window.c`, `window-commands.c`, `context-menu-commands.c`, `ephy-certificate-dialog.c`, `ephy-find-toolbar.c`, `ephy-notification*.c`, embed layer, webextension layer |
| GActions | 122 | `app.` 21, `win.` 46, `tab.` 9, `toolbar.` 13, `popup.` 33 (counted directly off `ephy-window.c`'s `g_action_map_add_action_entries` tables and `ephy-shell.c`) |
| Keyboard accelerators | 62 | action/accel pairs in `ephy-window.c` + `ephy-shell.c` |
| GSettings keys | 103 across 4 schemas | `data/org.gnome.epiphany.gschema.xml` |
| GResource entries | 37 `.ui`, 4 CSS, 1 GLSL, 30 SVG/`.gpa` | `src/resources/epiphany.gresource.xml.in` |
| `po/LINGUAS` | 110 | `po/LINGUAS` |
| `tests/*.c` | 18 | `git ls-tree -r --name-only origin/main | grep '^tests/.*\.c$' | wc -l` |

## Port component count

| Facet | Count | Source |
|---|---:|---|
| `lib/*.rb` files | 24 (21 flat files + `epiphany/application.rb` + `epiphany/rb/version.rb` + `epiphany.rb`) | `find lib -name '*.rb'` |
| GActions implemented | 8 (`app.` only) | `lib/epiphany/application.rb` |
| Keyboard accelerators wired | 8 | same file |
| GSettings keys | 103 (claimed ported in full) | `lib/settings.rb` |
| GResource / icon wiring | 0 — no icons, no `.ui`, no CSS beyond `style.css` | no resource bundle in the port at all |
| `po/` / gettext wiring | 0 | no `_()`/gettext markers anywhere in `lib/`; see `.reports/translation-parity.md` |
| `spec/*_spec.rb` | 0 — only `spec_helper.rb` and `README.md` | `find spec -type f` |

## Verdict on this axis

The identification itself (`.reports/component-inventory.md`) is accurate and
was built correctly — blueprints read first, C files read for code-built
chrome, one table per upstream area with upstream file, port file, kind, and
an honest `yes` / `partial` / `no` per row. I re-walked a sample of its claims
(window actions, GSettings keys, `po/LINGUAS`, test file count) against
`origin/main` directly and they check out.

The count that matters for parity: **of ~82 distinct upstream component files
(37 `.blp` + ~45 code-built), the port has built the chrome for zero of
them.** The 24 files that exist are all model/helper layer (bookmarks,
settings, search engines, permissions, encodings, sync helpers) or four small
standalone widgets (`notification.rb`, `notification_container.rb`,
`floating_bar.rb`, `search_entry.rb`) plus two interface mixins (`link.rb`,
`title_widget.rb`) and one dialog (`shortcuts_dialog.rb`, menu-data only, not
exercised through a real `Adw.ShortcutsDialog` widget tree beyond the 62-item
table). The main window, every toolbar, every dialog, every preferences page,
every data view, and the entire embed/browsing layer (`ephy-window.c`,
`ephy-web-view.c`, `ephy-embed.c`, the location entry, the tab view) are
absent. There is no component to compare on the four parity axes for any of
those files because none of them exist in the port yet — which is recorded
as a gap in `.reports/component-parity.md`, not as "identified and fine."
