# Component parity — epiphany-rb vs upstream `origin/main`

Audit date: 2026-11-08, against `ruby` @ `2b13b416b`. This is adversarial: it
assumes nothing is done until read and runs the drive script rather than
trusting its summary.

## Verdict: not at parity. The app cannot browse the web.

Epiphany is a web browser. On `ruby`, there is no `EphyEmbed`/`WebKitWebView`
layer anywhere — confirmed by grep (`grep -rn WebKitWebView lib/` → no hits;
`WebKitWebProcessExtension` is used only for the sandboxed web-process-side
message relay in `lib/web_process_extension.rb`, not for displaying pages).
Every tab is an `Adwaita::StatusPage` placeholder
(`lib/window.rb#placeholder_page`). Typing is not even possible — the header
bar's center widget is permanently `TitleBox` (read-only label), never the
editable `LocationEntry`, because `LocationEntry` does not exist in `lib/`.
A user cannot navigate anywhere a maintainer did not hand-code as a
`load_address` call. This is stated candidly in the commit message
("standing in for the WebKit-backed EphyEmbed layer this round does not
port") — it is not hidden, but it is also not a small gap: it is the
product's core function.

## Menu items that go nowhere

`PageMenuButton` (the header bar's hamburger menu, opened via a real,
reachable `Gtk::MenuButton`) lists 13 items. Clicking 8 of them is silently
inert because no action by that name is installed anywhere in the process
(verified by reading `lib/epiphany/application.rb`'s `build`, which installs
exactly `shortcuts` and `quit`, and `lib/window.rb`'s three action groups,
which install `new-tab`, `fullscreen`, `show-tab-overview`,
`navigation-back`, `navigation-forward`, `reload`, `close`):

| Menu item | Action | Installed? |
|---|---|---|
| Run in Background | `app.run-in-background` | ❌ |
| New Window | `app.new-window` | ❌ |
| New Incognito Window | `app.new-incognito` | ❌ |
| Reopen Closed Tab | `app.reopen-closed-tab` | ❌ |
| Fullscreen | `win.fullscreen` | ✅ |
| History | `app.history` | ❌ |
| Privacy Report | `win.privacy-report` | ❌ |
| Passwords | `win.passwords` | ❌ |
| Preferences | `app.preferences` | ❌ |
| Keyboard Shortcuts | `app.shortcuts` | ✅ |
| About Web | `app.about` | ❌ |
| Quit | `app.quit` | ✅ |

Upstream: every one of these resolves to a real dialog/window. A GTK
`Gio::SimpleAction` lookup miss on `activate_action` is a silent no-op, not a
crash, which is exactly why this would pass casual manual testing (menu
opens, looks right, most clicks "do nothing" in a way that looks like the
feature not being wired to this click rather than missing entirely) and why
it needs to be named explicitly here.

## Back/forward buttons are permanently disabled

`lib/window.rb#build_toolbar_actions` constructs `navigation-back` and
`navigation-forward` with `.tap { |a| a.enabled = false }`. Nothing in the
window, the two action-bar files, or `test/drive_epiphany.rb` ever sets
`enabled = true` on either action. `Page#can_go_back?`/`#can_go_forward?`
are implemented correctly and used by `navigate_back`/`navigate_forward`
themselves, but nothing connects them to the action's `enabled` state the
way upstream's `sync_chromes_visibility`/back-forward-list `notify` handlers
do. **The back and forward buttons in the action bars render but can never
be clicked**, in any build, regardless of how much navigation history a tab
has. The drive script's "window tabs and navigation" step calls
`app.window.navigate_back` / `navigate_forward` directly on the `Window`
object, never through the `toolbar.navigation-back` action a real button
click would invoke — so the dead button is invisible to the only check that
exercises this area.

## Downloads buttons have no popover

`ActionBarEnd#downloads_button` and `ActionBar#downloads_button` each build
a bare `Gtk::MenuButton` with an icon and tooltip and never set `.popover`.
`ActionBarEnd#show_downloads` (upstream: `ephy_action_bar_end_show_downloads`)
calls `downloads_button.popup`, which pops an empty/non-existent menu.
Upstream's button opens `EphyDownloadsPopover`, a full list of in-progress
and finished downloads; this port's downloads button is decorative.

## Bookmarks toggle button opens nothing

`ActionBarEnd#bookmarks_button` wires `clicked` to a bare
`@toggle_bookmarks` lambda the window passes in, and `Window#toggle_bookmarks`
(`lib/window.rb`) is defined as flipping the button's own `active` state —
`header_bar.action_bar_end.bookmarks_button.active = !...active?`. There is
no bookmarks popover or `bookmarks_dialog.rb` for it to reveal (confirmed
absent from `lib/`, same as the prior inventory found). The toggle button
toggles itself and nothing else.

## Things that are genuinely at parity in this slice

Verified by reading against upstream and by the drive run:

- `TitleBox` (`lib/title_box.rb`) — widget tree and `TitleWidget` contract
  match `src/ephy-title-box.c`.
- `TabView` (`lib/tab_view.rb`) — every exposed operation calls the real
  `AdwTabView` API (add/close/pin/reorder/iterate); no stubs found on read.
  (Its `attach_tab_bar` is real but dead code — see below.)
- `ActionHelper` (`lib/action_helper.rb`) — bitmask sensitivity logic matches
  `ephy_action_change_sensitivity_flags`, though nothing calls it yet.
- Fullscreen restore-button swap (`HeaderBar#sync_fullscreen`) — wired to a
  real `notify::fullscreened` signal, matches `fullscreen_changed_cb`.
- Window chrome bitmask (`CHROME_HEADER_BAR`/`CHROME_BOOKMARKS`/`CHROME_MENU`)
  — matches `EphyWindowChrome`'s subset this port reads.
- Everything the prior `component-parity.md`/`component-inventory.md`
  already verified at the model layer (bookmarks manager, search engine
  manager, permissions, downloads model, encodings, sync utils, certificate
  parsing via `gcr-rb`, notifications, OpenSearch parsing) — re-read, still
  accurate, not re-litigated here.

## Dead code found this pass

- `TabView#attach_tab_bar` — built, correct, never called. The window has no
  tab bar above its tab strip at all; `Window#content` returns
  `tab_overview` directly.
- `ActionHelper.change_sensitivity_flags` — ported, never invoked.

## Unchanged, still-missing surfaces (carried from the prior inventory, re-verified against current `lib/`)

Every dialog in the app (bookmarks, history, certificate, security, privacy
report, the full preferences dialog and its ~10 pages, both sync dialogs,
encoding dialog/row, webapp-additional-urls), the editable address bar
(`LocationEntry`/`LocationController`/suggestion model), the find toolbar's
UI half (only the bare `SearchEntry` widget exists; it is not wired into any
find-in-page flow), fullscreen box, site menu button, notebook/tab-overview
context menus, lockdown policy, session crash-restore, and the entire
WebExtensions UI layer are still absent. None of this is new to this pass;
it is restated because the task calls a narrow drive run a parity gap in its
own right, and none of these surfaces are reachable by any check, manual or
automated, in this repository.
