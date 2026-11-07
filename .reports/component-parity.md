# Component parity — epiphany-rb vs origin/main

Adversarial check: for every upstream component, does the port build the same
widget, in the same count, with the same CSS classes, the same signals/actions,
and the same translatable text? Verdict per component area below; "gap" means
the axis cannot even be evaluated because the component does not exist.

## Application shell (`lib/epiphany/application.rb` ← `ephy-shell.c` + `ephy-main.c`)

- **Count**: upstream installs 21 `app.` actions with accelerators (About,
  help, preferences, new window, new incognito window, import/export
  bookmarks, quit, shortcuts, etc.). Port installs **8**. 13 `app.` actions
  are gap, including `app.preferences` (opens the entire preferences dialog —
  itself unported) and `app.about` (About dialog, unported).
- **Style**: n/a — no dialogs to carry CSS classes for the missing 13.
- **Behaviour**: the 8 that exist match upstream's accelerators (confirmed
  against `ephy-shell.c`'s accel table in the existing inventory). The 13
  missing ones are not partially stubbed; they simply do not exist as
  actions, so pressing their keyboard shortcuts upstream users rely on
  (e.g. opening preferences) does nothing in the port.
- **Text**: n/a for the missing actions.
- **Verdict: gap — 13 of 21 `app.` actions missing.**

## Main window (`ephy-window.c` → `lib/window.rb`)

- Upstream: `Adw.ApplicationWindow` + `Adw.OverlaySplitView`, `Adw.TabOverview`,
  `Adw.TabBar`, `Adw.ToastOverlay`, `Adw.Breakpoint`, a `Gtk.Revealer`, 4
  dynamic CSS classes (`narrow`, `incognito-mode`, `devel`,
  `automation-mode`), 46 `win.` + 9 `tab.` + 13 `toolbar.` + 33 `popup.`
  actions (101 actions total), a password-generator popover, mouse-gesture and
  scroll controllers.
- Port: `lib/window.rb` does not exist. `Epiphany::Application#build` shows a
  bare `Adw.StatusPage` in place of the window's real content (confirmed in
  the drive report's own words: "the window's content is still a status
  page").
- **Verdict: gap, total.** 0 of 101 window-level actions exist. 0 of 4 dynamic
  CSS classes exist. No tab strip, no split view, no toast overlay, no
  password-generator popover exists to check style/behaviour/text against.

## Toolbars and location entry

`action-bar.rb`, `action_bar_start.rb`, `action_bar_end.rb`,
`location_entry.rb`, `location_controller.rb`, `suggestion_model.rb`,
`page_menu_button.rb`, `site_menu_button.rb`, `notebook_context_menu.rb`,
`tab_overview_menu.rb` — **none exist.** `suggestion.rb` (the list-item model)
exists and is exercised by the drive script, but `SuggestionModel`, the
`Gtk.ListView` + `Gtk.SingleSelection` + factory that actually renders
suggestions in a popover, does not. A user cannot type a URL, see the address
bar, or get a suggestion in the port today — there is no address bar.
**Verdict: gap, total**, for every file in this group except the one leaf
model class.

## Downloads

`downloads_popover.rb`, `download_widget.rb`, `downloads_paintable.rb`,
`download.rb`, `downloads_manager.rb` — **none exist.** No download can be
started, shown, or managed. **Verdict: gap, total.**

## Bookmarks

- Model layer (`bookmark.rb`, `bookmarks_manager.rb`, `bookmarks_import.rb`,
  `bookmarks_export.rb`): ported, and the manager/model pair is exercised by
  the drive script (add, find-by-url, tag indexing, remove). This is the
  strongest area of the port.
- UI layer (`bookmarks_dialog.rb`, `bookmark_row.rb`, `bookmark_properties.rb`):
  **none exist.** There is no sidebar/dialog, no row widget with its drag
  handle and move menu, no properties dialog with its tag picker. A user of
  the port can manage bookmarks only through the Ruby API, never through a
  window. The empty state (`Adw.StatusPage` "No Bookmarks") — a component in
  its own right per the skill's own guidance — does not exist either, because
  nothing renders bookmarks at all.
- **Verdict: model has parity-eligible candidates (see test-parity for whether
  it's actually pinned); UI is a total gap, including the empty state.**

## History

`history_dialog.rb`, `history_dialog_row.rb` — **neither exists**, and there
is no history model/service either (`lib/ephy-history-service*` → no
`history_service.rb`, no `sqlite_connection.rb`). This is not "dialog missing,
model present" — the entire history subsystem, model included, is absent.
**Verdict: gap, total**, including both empty states (`No History Found`,
`No Results Found`).

## Preferences (6 pages + dialog + supporting rows/dialogs)

`prefs_dialog.rb`, `prefs_general_page.rb`, `prefs_privacy_page.rb`,
`prefs_appearance_page.rb`, `prefs_features_page.rb`,
`prefs_extensions_page.rb`, `prefs_search_engine_page.rb`,
`search_engine_listbox.rb`, `search_engine_row.rb`, `lang_row.rb`,
`prefs_lang_dialog.rb`, `webapp_additional_urls_dialog.rb`,
`extension_view.rb` — **none exist.** There is no way to open Preferences in
the port at all (`app.preferences` is one of the 13 missing app actions
above). Every `Adw.SwitchRow`, every `Adw.ComboRow`, every empty state in this
group (no-extensions card) is a total gap.

## Data views (`data_view.rb`, `clear_data_view.rb`, `passwords_view.rb`,
`autofill_view.rb`, `autofill_storage.rb`) — none exist.

## Site, security, privacy (`security_dialog.rb`, `certificate_dialog.rb`,
`privacy_report.rb`, `client_certificate_manager.rb`) — none exist. Model
layer: `permissions_manager.rb` exists and is exercised by the drive script
(set/get a permission, permitted-origins listing) — the one component in this
group with a real candidate for parity.

## Firefox Sync (`firefox_sync_dialog.rb`, `synced_tabs_dialog.rb`) — neither
exists. `sync_utils.rb` (helper, hex/base64 round trips) exists and is
exercised.

## Encoding — model (`encoding.rb`, `encodings.rb`) ported and exercised
(built-in table load, UTF-8 lookup). UI (`encoding_dialog.rb`,
`encoding_row.rb`) — neither exists.

## Web extensions — entire subsystem (`web_extension*.rb`,
`browser_action*.rb`, `indicator_bin.rb`, `gizmo.rb`, 11-file `web_extension_api/`)
absent. 0 of 11 API files.

## Embed layer (page chrome) — `embed.rb`, `web_view.rb` (the actual WebKit
wrapper — **the thing that renders web pages**), `find_toolbar.rb`,
`about_handler.rb`, `reader_handler.rb`, `view_source_handler.rb`,
`embed_autofill.rb`, `embed_prefs.rb`, `filters_manager.rb` — **none exist.**
`search_entry.rb` and `floating_bar.rb` exist and are exercised as standalone
widgets. The six documented upstream web-view error states (invalid TLS,
missing file, page crash, network error, process crash, unresponsive process)
have no port-side counterpart because there is no `WebView` class to carry
them.

## Notifications — `notification.rb` + `notification_container.rb` exist,
match upstream's class shape (singleton container, as upstream), and are
exercised through the app's real instances per the drive report. This is a
second genuinely strong area.

## Non-UI support

- Settings (103 keys, 4 schemas): claimed complete; spot-checked against
  `data/org.gnome.epiphany.gschema.xml` key count in the existing inventory —
  consistent.
- GResource bundle, icons, `about.css`/`error.css`/`style-elementary.css`: not
  wired at all. Only `style.css` is ported (as `lib/styles.rb`).
- Search provider (`shell_search_provider.rb`), web-app D-Bus provider
  (`webapp_provider.rb`), snapshot/favicon services, SQLite/history storage:
  none exist.

## Summary verdict

**Not clean.** Of roughly 82 distinct upstream UI component files, the port
has shipped UI for **zero** of them — every window, dialog, page, popover,
and menu in the inventory is missing. The 24 files that do exist are almost
entirely model/helper classes (bookmarks, settings, search engines,
permissions, encodings, sync helpers) plus five small standalone widgets
(notification, notification container, floating bar, search entry,
shortcuts-dialog data) and two interface mixins. None of the four
component-parity axes (count, style, behaviour, text) can be evaluated as
"met" for the missing components because there is no component on the port
side to measure — that absence is itself the finding, not a pass by default.
No empty state and no error state listed in the upstream inventory exists in
the port, because none of the screens that would show them exist.
