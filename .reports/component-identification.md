# Component identification — epiphany-rb vs upstream `origin/main`

Audit date: 2026-11-08. Scope: full re-pass after `2b13b416b` ("Port the
browser window: tab strip, header bar, action bars and page menu"), which is
the newest commit on `ruby` and the only one not covered by the previous
`.reports/component-inventory.md` (written at `e02b16bd5`, one commit
earlier). This file supersedes that inventory's totals for the window layer;
the rest of that document's row-by-row table is still accurate and is
incorporated by reference rather than retyped.

## Method

Upstream has no `.blp`/`.ui` for most of the window chrome below
`src/resources/gtk/*.blp` — read directly via `git show origin/main:<path>`
for each `.c`/`.blp` pair named in the existing inventory, and diffed against
the 9 files the latest commit added: `lib/window.rb`, `lib/header_bar.rb`,
`lib/title_box.rb`, `lib/tab_view.rb`, `lib/page_menu_button.rb`,
`lib/action_bar.rb`, `lib/action_bar_start.rb`, `lib/action_bar_end.rb`,
`lib/action_helper.rb`. No GIR symbol table was rebuilt for this pass (the
new files are plain `Gtk`/`Adwaita` boxes, buttons, menu buttons and one
`Adwaita::TabView`/`Adwaita::TabButton`/`Adwaita::Clamp` — nothing novel to
classify), so counts below come from direct reading, not `component-scan.sh`.

## New since last inventory

## `lib/window.rb` — the browser window (ported from `src/ephy-window.c`)

| Widget | x | CSS | Signals/actions | Notes |
|---|---:|---|---|---|
| `Gtk::ApplicationWindow`/`Adwaita` window (via `gtk_window`) | 1 | — | `notify::fullscreened` | — |
| `Adwaita::TabOverview` (`tab_overview`) | 1 | — | — | content root |
| Action groups `win`/`toolbar`/`tab` | 3 groups, 6 actions total | — | `win.new-tab`, `win.fullscreen`, `win.show-tab-overview`, `toolbar.navigation-back` (starts disabled, never re-enabled), `toolbar.navigation-forward` (same), `toolbar.reload`, `tab.close` | **`win.privacy-report` and `win.passwords`, both referenced by `PageMenuButton#browsing_section`, are not among them** — see component-parity |

`navigation-back`/`navigation-forward` are each built `.tap { |a| a.enabled =
false }` and nothing in `window.rb`, `action_bar_start.rb` or the drive
script ever sets `enabled = true`. Upstream enables/disables these from
`WebKitBackForwardList` changes; this port has no equivalent re-enable path
at all, so the back/forward buttons are permanently dead regardless of
navigation history (`Page#can_go_back?`/`#can_go_forward?` are computed
correctly but nothing reads them to drive the action's `enabled`).

## `lib/header_bar.rb` (`src/ephy-header-bar.c`)

| Widget | x | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk::Box` (root) | 1 | — | — | |
| `Adwaita::HeaderBar` | 1 | — | — | |
| `Adwaita::Clamp` | 1 | — | — | max-size 860, tightening 560 — matches upstream constant |
| `Gtk::Button` (restore) | 1 | — | `action_name = win.fullscreen` | visible only `fullscreened?` |

Composite children: `ActionBarStart`, `ActionBarEnd`, `PageMenuButton`,
`TitleBox` — each identified separately below/in the prior inventory.
Upstream's header bar picks `EphyLocationEntry` **or** `TitleBox` depending on
`EphyEmbedShellMode`; this port's comment at `lib/header_bar.rb:18-19`
states plainly that it "always shows the read-only TitleBox" because
`LocationEntry` is not ported. That is a real behavioural divergence, not a
cosmetic one: the header bar's center widget can never be typed into.

## `lib/title_box.rb` (`src/ephy-title-box.c`) — ✅ faithful

`Gtk::Box` > `Gtk::Label.title`, `Gtk::Box.subtitle` >
`Gtk::MenuButton.entry-icon` (security button, hidden until a security level
is set) + `Gtk::Label` (address). Matches upstream's widget tree and the
`TitleWidget` contract (`address`, `security_level`, `reset`). No gap found
here.

## `lib/tab_view.rb` (`src/ephy-tab-view.c`) — ✅ operations real

Wraps one `Adwaita::TabView`. All listed operations (`add_tab`, `close_*`,
`pin`/`unpin`, `next`, iteration, `pinned?`) call the real `AdwTabView` API,
confirmed by reading — no stubs. Two real gaps:

- `attach_tab_bar` exists and wires an `Adwaita::TabBar`'s visibility to the
  `tabs-bar-visibility-policy`/`expand-tabs-bar` keys, but **nothing calls
  it** — grep `attach_tab_bar` outside its own definition and the drive
  script returns no hits in `lib/` or `lib/epiphany/application.rb`. The tab
  bar itself is never attached to the window; `window.rb`'s `content` is
  `tab_overview` directly with no tab bar above the strip.
- Context-menu-opened page tracking (`current_page`) is a real stand-in, but
  the comment at `tab_view.rb:146-148` admits there is no context menu wired
  at all yet (`notebook-context-menu.blp` is still unported, confirmed absent
  from `lib/`).

## `lib/page_menu_button.rb` (`src/ephy-page-menu-button.c`)

`Gtk::MenuButton` + `Gtk::PopoverMenu` over a `Gio::Menu` with 5 sections, 13
items total, matching the upstream `.blp`'s item set minus the web-app /
window-management prunes the comment describes. **8 of the 13 items target
an action that is never installed anywhere in the port**
(`app.run-in-background`, `app.new-window`, `app.new-incognito`,
`app.reopen-closed-tab`, `app.history`, `win.privacy-report`, `win.passwords`,
`app.preferences`, `app.about`; `app.quit`, `app.shortcuts` and `win.fullscreen`
are the only ones that resolve). See component-parity for the user-facing
consequence.

## `lib/action_bar_start.rb` / `lib/action_bar_end.rb` / `lib/action_bar.rb`

Three `Gtk::Box` toolbars: back/forward (`toolbar.navigation-*`, dead per
above), combined stop/reload (`toolbar.reload` — exists, but implemented as
"refresh the title widget", not an actual reload of anything, since there is
no page to reload), a bookmarks `Gtk::ToggleButton` (wired only to a bare
`@toggle_bookmarks` lambda that flips its own `active` state — no bookmarks
popover/dialog opens), a tab-overview button (`win.show-tab-overview`,
resolves), a downloads `Gtk::MenuButton` whose `popover` is **never set** —
`lib/action_bar_end.rb#downloads_button` and `lib/action_bar.rb#downloads_button`
both build a bare `Gtk::MenuButton` with icon/tooltip and no `.popover =`,
so clicking either does nothing visible even though `ActionBarEnd#show_downloads`
calls `downloads_button.popup` on a menu button with no menu model attached.

## `lib/action_helper.rb` (`src/ephy-action-helper.c`) — ✅ faithful, unused

The bitmask logic matches upstream's `ephy_action_change_sensitivity_flags`.
No caller anywhere in `lib/` currently invokes `ActionHelper.change_sensitivity_flags`
— it is ported but not yet wired into any of the new action groups, so the
multi-reason-disable behaviour it exists for is not exercised by anything,
including the drive script.

## Still entirely unported (unchanged from the prior inventory, re-confirmed against current `lib/` listing)

Re-verified by `ls lib/` against the prior inventory's ❌ rows: every dialog
(bookmarks, history, certificate, security, privacy report, the 6-page
preferences dialog, both sync dialogs, encoding dialog, webapp-urls dialog),
`location_entry.rb`/`location_controller.rb`/`suggestion_model.rb` (the
actual editable address bar), `fullscreen_box.rb`, `site_menu_button.rb`,
`context_menu_commands.rb`, `window_commands.rb`,
`notebook_context_menu.rb`, `tab_overview_menu.rb`, `lockdown.rb`,
`session.rb` (crash-restore), the entire web-extensions UI layer
(`web_extension*.rb`, `browser_action*.rb`, `indicator_bin.rb`, `gizmo.rb`),
every row type (`bookmark_row.rb`, `history_dialog_row.rb`,
`encoding_row.rb`, `download_widget.rb`, `downloads_popover.rb`,
`downloads_paintable.rb`), the about/error static pages, and app metadata
(`.desktop`/`.metainfo`) remain absent from `lib/`, exactly as the prior
inventory found. None of these appear in `lib/` after the latest commit.
