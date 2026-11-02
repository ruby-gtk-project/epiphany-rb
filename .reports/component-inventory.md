# epiphany — upstream component inventory

Survey of every user-facing component on `origin/main` (Epiphany / GNOME Web,
C + blueprint), mapped to the `lib/*.rb` file it should become on the `ruby`
branch, with its present state.

Method: `component-identification` skill. Upstream tree read with
`git ls-tree -r --name-only origin/main` / `git show origin/main:<path>`, the
37 `.blp` files read first (they *are* the component inventory), then
`scripts/component-scan.sh` over an exported copy of the tree (4814 rows), then
the C files for everything built in code (`ephy-window.c`, `window-commands.c`,
`ephy-certificate-dialog.c`, `ephy-find-toolbar.c`, `ephy-notification.c`, …).

## Totals

| | Upstream | `ruby` branch |
|---|---:|---:|
| Component files (source + its `.blp`) | 37 blueprints + ~45 C widget files | 22 |
| `lib/*.rb` port files | — | 23 (21 flat `lib/*.rb` + `epiphany/application.rb` + `epiphany/rb/version.rb`) |
| GActions | 122 (`app.` 21, `win.` 46, `tab.` 9, `toolbar.` 13, `popup.` 33) | 8 `app.` |
| Keyboard accelerators | 62 action/accel pairs (`ephy-window.c` + `ephy-shell.c`) | 8 |
| Shortcuts-dialog items | 62 items in 6 sections | 62 in 6 sections (`lib/shortcuts_dialog.rb`) |
| GSettings schemas / keys | 4 schemas, 103 keys (`data/org.gnome.epiphany.gschema.xml`) | 4 schemas, 103 keys (`lib/settings.rb`) |
| GResource entries | `src/resources/epiphany.gresource.xml.in` — 37 `.ui`, 4 CSS, 1 GLSL, 30 SVG/`.gpa` icons, `about.ini` | `style.css` ported as `lib/styles.rb`; icons not wired |
| Translations | `po/` 110 LINGUAS, `po/POTFILES.in` 117 source files | not wired |

State of the port as of this revision: the **model, settings, bookmarks,
search-engine and notification layers are ported** (21 flat `lib/*.rb`), and
`lib/epiphany/application.rb` owns one process-wide copy of each model plus 8
`app.` actions with their accelerators. **No browsing UI exists yet** — the
window's content is still a status page, so every window, toolbar, dialog,
preferences page and data view below is missing.

## Port file mapping

The pilot (`gnome-contacts-rb`) puts one upstream source file in one flat
`lib/<thing>.rb` with a top-level class, `# frozen_string_literal: true`,
`require 'adwaita'`, and a comment naming the upstream file. Epiphany's
`ephy-` prefix is dropped; a `.blp` and its `.c` merge into one Ruby file.

### Application and shell

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-shell.c` + `.h` | `lib/epiphany/application.rb` | application — 21 `app.` actions, accels, About, help, preferences entry | partial — 8 of 21 `app.` actions with accels, owns the ported models; no About/help/preferences |
| `src/ephy-main.c` | `lib/main.rb` | entry point / CLI options | no |
| `src/ephy-session.c` | `lib/session.rb` | session save/restore, reopen-closed-tab | no |
| `src/ephy-lockdown.c` | `lib/lockdown.rb` | action enable/disable policy | no |
| `src/window-commands.c` + `.h` | `lib/window_commands.rb` | all `win.`/`tab.`/`toolbar.`/`popup.` handlers; hosts the About dialog (`Adw.AboutDialog` from appdata), 7 `Gtk.FileDialog`s, 4 `Adw.AlertDialog`s, 4 `Adw.Toast`s | no |
| `src/context-menu-commands.c` | `lib/context_menu_commands.rb` | 33 `popup.` handlers | no |
| `embed/ephy-embed-shell.c` | `lib/embed_shell.rb` | web context, managers | no |

### Main window

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-window.c` + `.h` | `lib/window.rb` | window — `Adw.ApplicationWindow` + `Adw.OverlaySplitView`, `Adw.TabOverview`, `Adw.TabBar`, `Adw.ToastOverlay`, `Adw.Breakpoint`, `Gtk.Revealer`; CSS `narrow`, `incognito-mode`, `devel`, `automation-mode`; 46 `win.` + 9 `tab.` + 13 `toolbar.` + 33 `popup.` actions; `Gtk.EventControllerKey`, `Gtk.EventControllerScroll`, `Gtk.GesturePan`; password-generator popover (`Adw.PasswordEntryRow`, `Adw.SwitchRow`) | no |
| `src/ephy-header-bar.c` + `.h` | `lib/header_bar.rb` | header bar — `Adw.HeaderBar`, `Adw.Clamp`, 2 `Adw.Bin`, `Gtk.Button` | no |
| `src/ephy-title-box.c` + `.h` | `lib/title_box.rb` | widget — `Adw.Bin`, 2 `Gtk.Box`, 2 `Gtk.Label`, `Gtk.MenuButton`; CSS `title`, `subtitle`, `entry-icon` | no |
| `src/ephy-title-widget.c` + `.h` | `lib/title_widget.rb` | interface shared by title box and location entry | **yes** |
| `src/ephy-fullscreen-box.c` + `.h` | `lib/fullscreen_box.rb` | widget — `Adw.ToolbarView`, element name `fullscreenbox`, `Gtk.EventControllerMotion`, `Gtk.GestureClick` | no |
| `src/ephy-tab-view.c` + `.h` | `lib/tab_view.rb` | widget — `Adw.TabView` in `Adw.Bin`, `Gtk.Button` `flat` | no |
| `src/ephy-mouse-gesture-controller.c` | `lib/mouse_gesture_controller.rb` | controller — mouse gestures | no |
| `src/ephy-link.c` + `.h` | `lib/link.rb` | interface — link-opening | **yes** |

### Toolbars and the location entry

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-action-bar.c` + `src/resources/gtk/action-bar.blp` | `lib/action_bar.rb` | action bar (narrow/mobile) — `Adw.Bin` > `Gtk.Box` `toolbar`, 6 `Gtk.Button` + `Adw.TabButton` + `Gtk.MenuButton` + `Gtk.Image`, all CSS `toolbar-button`; `toolbar.navigation-back/-forward`, `win.tabs-view`, `win.bookmarks`; 2 `Gtk.GestureClick` (buttons 2, 3) + `Gtk.GestureLongPress` per nav button | no |
| `src/ephy-action-bar-start.c` + `action-bar-start.blp` | `lib/action_bar_start.rb` | toolbar start — nav box, combined stop/reload, homepage, new-tab buttons, site-menu button, placeholder; CSS `navigation-box`, `toolbar-button` | no |
| `src/ephy-action-bar-end.c` + `action-bar-end.blp` | `lib/action_bar_end.rb` | toolbar end — downloads `Gtk.Revealer` + `Gtk.MenuButton` (`image-button`, `toolbar-button`), browser-actions `Gtk.Popover` `menu` > `Gtk.Stack` > `Gtk.ScrolledWindow` > `Gtk.ListBox` (`row-activated`) and a popup-view `Gtk.CenterBox` with back `Gtk.Button` `flat` + `Gtk.Label` `heading`, overview + bookmarks buttons | no |
| `src/ephy-location-entry.c` + `location-entry.blp` | `lib/location_entry.rb` | location entry — `Gtk.Stack` (`display`/`edit`), `Gtk.Overlay`, linked box with site-menu button + url `Gtk.Button` (`entry-icon`, `text-button`) + combined stop/reload, `Gtk.ProgressBar` (`osd`, `progress-indicator`), `Gtk.Entry` with `extra-menu` (`clipboard.paste-and-go`), suggestions `Gtk.Popover` (`menu`, `suggestions`) > `Gtk.ListView` + `Gtk.SingleSelection` + `BuilderListItemFactory` item (`Gtk.Grid`, 2 `Gtk.Image`, 3 `Gtk.Label` incl. `dim-label caption`, `Gtk.GestureClick`); `Gtk.EventControllerKey`, `Gtk.EventControllerFocus` | no |
| `src/ephy-location-controller.c` + `.h` | `lib/location_controller.rb` | controller — binds entry to the active web view | no |
| `src/ephy-suggestion-model.c` + `lib/ephy-suggestion.c` | `lib/suggestion_model.rb`, `lib/suggestion.rb` | list model + item — URL-bar suggestions (history, bookmarks, open tabs, search) | partial — `suggestion.rb` **yes**, `suggestion_model.rb` no |
| `src/ephy-page-menu-button.c` + `page-menu-button.blp` | `lib/page_menu_button.rb` | menu button + `page_menu` `Gio.MenuModel` — 5 sections, 17 items incl. `_Web Apps` submenu, `hidden-when: action-disabled` on run-in-background / uninstall-web-app | no |
| `src/ephy-site-menu-button.c` + `site-menu-button.blp` | `lib/site_menu_button.rb` | menu button — `Gtk.Button` with `Gtk.Image`/`Svg` paintable from a `.gpa`; `popover_menu` with a `custom: "zoom_level"` slot hosting a `linked page-menu-zoom-box` of 3 `Gtk.Button` + zoom `Gtk.Label`; `items_section` with 7 items (find, print, mute tab, edit bookmark, add search engine, encoding, security & permissions) | no |
| `src/resources/gtk/notebook-context-menu.blp` | `lib/notebook_context_menu.rb` | menu — 10 `tab.`/`toolbar.` items in 3 sections | no |
| `src/resources/gtk/tab-overview-menu.blp` | `lib/tab_overview_menu.rb` | menu — 4 `app.` items in 2 sections | no |
| `src/resources/gtk/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | dialog — `Adw.ShortcutsDialog`, 6 `Adw.ShortcutsSection` (General 11, Navigation 7, Tabs 9, Miscellaneous 8, View 7, Editing 12 = 62 `Adw.ShortcutsItem`) | **yes** |

### Downloads

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-downloads-popover.c` + `.h` | `lib/downloads_popover.rb` | popover — `Gtk.Popover` (`menu`, `background`), `Gtk.ScrolledWindow` > `Gtk.ListBox`, 2 `Gtk.ListBoxRow`, clear-all `Gtk.Button` | no |
| `src/ephy-download-widget.c` + `.h` | `lib/download_widget.rb` | row — `Adw.Bin` > `Gtk.Grid`, `Gtk.Image`, 2 `Gtk.Label`, `Gtk.ProgressBar`, `Gtk.Button` `circular`, `Gtk.DragSource` | no |
| `src/ephy-downloads-paintable.c` | `lib/downloads_paintable.rb` | paintable — animated downloads-button icon | no |
| `embed/ephy-download.c`, `embed/ephy-downloads-manager.c` | `lib/download.rb`, `lib/downloads_manager.rb` | model | no |

### Bookmarks

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/bookmarks/ephy-bookmarks-dialog.c` + `bookmarks-dialog.blp` | `lib/bookmarks_dialog.rb` | sidebar/dialog — `Adw.Bin` > `Adw.ToolbarView` + `Adw.HeaderBar` (edit `Adw.ButtonContent`, done, close `view-sidebar-end-symbolic`, options `Gtk.MenuButton` `view-more-symbolic`), `Adw.ToastOverlay`, `Gtk.Label` `title-1`, `Gtk.SearchEntry` + `Gtk.EventControllerKey`, `Gtk.ScrolledWindow` `undershoot-top`, `Gtk.Stack` with 4 pages: `default` / `searching_bookmarks` / `tag_detail` (back `Gtk.Button` `flat`, `Gtk.Label` `heading`, `Gtk.ListBox` `boxed-list`) / **empty state** `Adw.StatusPage` `No Bookmarks` (`compact`, `dim-label`); `options_menu` = import/export | no |
| `src/bookmarks/ephy-bookmark-row.c` + `bookmark-row.blp` | `lib/bookmark_row.rb` | row — `Adw.ActionRow` + favicon `Gtk.Image`, drag handle `Gtk.Image` + `Gtk.DragSource`, remove/properties `Gtk.Button` `flat`, move `Gtk.MenuButton` `flat` + `move_menu` (`row.move-up`, `row.move-down`) | no |
| `src/bookmarks/ephy-bookmark-properties.c` + `bookmark-properties.blp` | `lib/bookmark_properties.rb` | dialog — `Adw.Dialog` > `Adw.NavigationView` with Bookmark page (`Adw.EntryRow` name/address, tags `Adw.ActionRow`, remove `Adw.ButtonRow` `destructive-action`, cancel/add `Gtk.Button` `suggested-action`) and Tags page (`Adw.EntryRow` add-tag + `Gtk.Button` `flat`, `Gtk.ListBox` `boxed-list undershoot-top`); `Gtk.ShortcutController` | no |
| `src/bookmarks/ephy-bookmark.c`, `-manager.c`, `-import.c`, `-export.c` | `lib/bookmark.rb`, `lib/bookmarks_manager.rb`, `lib/bookmarks_import.rb`, `lib/bookmarks_export.rb` | model / import / export | **yes** (all four) |

### History

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-history-dialog.c` + `history-dialog.blp` | `lib/history_dialog.rb` | dialog — `Adw.Dialog` > `Adw.ToolbarView`, `Gtk.Stack` of two `Adw.HeaderBar`s (normal: clear `Adw.ButtonContent`, selection-mode, search `Gtk.ToggleButton`; selection: select-all, cancel, search), `Gtk.SearchBar` + `Adw.Clamp` + `Gtk.SearchEntry`, `Adw.ToastOverlay`, `Gtk.Stack`: list (`Gtk.ScrolledWindow` `edge-reached` > `Gtk.Viewport` > `Adw.Clamp` > `Gtk.ListBox` `boxed-list`), `Adw.Spinner` loading, **empty states** `Adw.StatusPage` `No History Found` and `No Results Found`, selection `Gtk.Revealer` > `Gtk.ActionBar` with delete `destructive-action` + open buttons; `Gtk.EventControllerKey` | no |
| `src/ephy-history-dialog-row.c` + `.h` | `lib/history_dialog_row.rb` | row — `Adw.ActionRow` subclass, built in C | no |

### Preferences

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/preferences/ephy-prefs-dialog.c` + `prefs-dialog.blp` | `lib/prefs_dialog.rb` | dialog — `Adw.PreferencesDialog` hosting the 6 pages; routes `webapp-additional-row-activated`, `autofill-row-activated`, `clear-data-row-activated` | no |
| `src/preferences/prefs-general-page.c` + `prefs-general-page.blp` | `lib/prefs_general_page.rb` | page — `Adw.PreferencesPage` `General`, 10 `Adw.PreferencesGroup`: Web App (icon `Adw.ActionRow` + `Gtk.Image`, 2 `Adw.EntryRow`, additional domains row), Web Content (3 `Adw.SwitchRow`), Homepage (3 `Adw.ActionRow` + 3 `Gtk.CheckButton` + custom `Gtk.Entry`), Downloads (`Adw.SwitchRow`, folder `Adw.ActionRow` with `dim-label` icon/label), Search (2 `Adw.ComboRow` + default engines group), Session (2 `Adw.SwitchRow`), Browsing (3 `Adw.SwitchRow`), Languages (`Gtk.ListBox` `boxed-list`), spell checking, Developer (2 `Adw.SwitchRow`) | no |
| `src/preferences/prefs-privacy-page.c` + `prefs-privacy-page.blp` | `lib/prefs_privacy_page.rb` | page — `Privacy`: Web Tracking (2 `Adw.SwitchRow`), Search Suggestions, Personal Data (Website Data row), Forms and Autofill (`Adw.SwitchRow` + Autofill Data row) | no |
| `src/preferences/prefs-appearance-page.c` + `prefs-appearance-page.blp` | `lib/prefs_appearance_page.rb` | page — `Appearance`: Fonts (`Adw.ExpanderRow` + 3 `Adw.ActionRow` + 3 `Gtk.FontDialogButton`), Reader Mode (2 `Adw.ComboRow`), Style (2 `Adw.SwitchRow` + 2 edit `Gtk.Button` `flat`, default-zoom `Adw.ComboRow` + `Gtk.StringList`), `Gtk.SizeGroup` | no |
| `src/preferences/prefs-features-page.c` + `prefs-features-page.blp` | `lib/prefs_features_page.rb` | page — `Features`: `Adw.ButtonRow` Reset All + rows generated per WebKit feature (repeater) | no |
| `src/preferences/prefs-extensions-page.c` + `prefs-extensions-page.blp` | `lib/prefs_extensions_page.rb` | page — `Extensions`: add-extension `Adw.ActionRow`, `dim-label` note, `Gtk.Stack` list (`Gtk.ListBox` `boxed-list`) / **empty state** (`card`, `dim-label`) | no |
| `src/preferences/prefs-search-engine-page.c` + `prefs-search-engine-page.blp` | `lib/prefs_search_engine_page.rb` | page — `Adw.NavigationPage` + `Adw.HeaderBar`, name/address/shortcut `Adw.EntryRow`, info `Gtk.MenuButton` `flat`, `Adw.ButtonRow` | no |
| `src/preferences/ephy-search-engine-listbox.c` + `search-engine-listbox.blp` | `lib/search_engine_listbox.rb` | widget — `Adw.Bin` > `Gtk.ListBox` `boxed-list`; builds 2 `Adw.ActionRow`, `Adw.ButtonRow`, `Gtk.CheckButton` in code | no |
| `src/preferences/ephy-search-engine-row.c` + `search-engine-row.blp` | `lib/search_engine_row.rb` | row — `Adw.ActionRow` + edit `Gtk.Button` `flat` | no |
| `src/preferences/ephy-lang-row.c` + `lang-row.blp` | `lib/lang_row.rb` | row — `Adw.ActionRow`, drag handle + `Gtk.DragSource`, move `Gtk.MenuButton` `flat` + `move_menu`, delete `Gtk.Button` `flat` | no |
| `src/resources/gtk/prefs-lang-dialog.blp` | `lib/prefs_lang_dialog.rb` | dialog — `Adw.Dialog` Add Language, `Adw.HeaderBar` + cancel/add `Gtk.Button` `suggested-action`, `Gtk.ScrolledWindow` `frame` > `Gtk.ListView` | no |
| `src/preferences/webapp-additional-urls-dialog.c` + `.blp` | `lib/webapp_additional_urls_dialog.rb` | page — `Adw.NavigationPage` Additional URLs, `Adw.EntryRow` + add `Gtk.Button` `flat`, URL rows (repeater) | no |
| `src/preferences/extension-view.c` + `extension-view.blp` | `lib/extension_view.rb` | page — `Adw.NavigationPage`, `Adw.HeaderBar` + `Adw.WindowTitle` + `Gtk.MenuButton` (`prefs.inspector` menu), author/version/homepage `Adw.ActionRow`s with `dim-label` labels, enabled `Adw.SwitchRow`, remove `Adw.ButtonRow` `destructive-action` | no |

### Data views

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/preferences/ephy-data-view.c` + `data-view.blp` | `lib/data_view.rb` | base page — `Adw.NavigationPage` > `Adw.ToolbarView`, `Adw.HeaderBar` + search `Gtk.ToggleButton` + options `Gtk.MenuButton`, `Gtk.SearchBar` + `Adw.Clamp` + `Gtk.SearchEntry`, `Adw.ToastOverlay` > `Gtk.Stack` (loading `Adw.Spinner`, **empty** `Adw.StatusPage`, **no-results** `Adw.StatusPage`), `Gtk.ActionBar` + clear `Gtk.Button` `destructive-action` | no |
| `src/preferences/clear-data-view.c` + `clear-data-view.blp` | `lib/clear_data_view.rb` | page — `$EphyDataView` subclass `Website Data`, `Gtk.TreeView` + `Gtk.TreeSelection` + 2 `Gtk.TreeViewColumn` in a `frame`, warning `Gtk.Label` `heading` | no |
| `src/ephy-passwords-view.c` + `passwords-view.blp` | `lib/passwords_view.rb` | dialog — `Adw.Dialog` wrapping `$EphyDataView` `Passwords`, `Gtk.ListBox` `boxed-list`, row popup menu (copy password/username), options menu (import/export) | no |
| `src/preferences/autofill-view.c` + `autofill-view.blp` | `lib/autofill_view.rb` | page — `Adw.NavigationPage` Autofill Data, clear-all `Gtk.Button` `destructive-action`, 4 `Adw.PreferencesGroup` (Personal 3, Contact 3, Address 6 + `Adw.ComboRow` country, Credit Card `Adw.ComboRow` + 3 `Adw.EntryRow`) | no |
| `lib/autofill/ephy-autofill-storage.c` | `lib/autofill_storage.rb` | model | no |

### Site, security and privacy

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-security-dialog.c` + `security-dialog.blp` | `lib/security_dialog.rb` | dialog — `Adw.Dialog` > `Adw.HeaderBar` + `Adw.ViewSwitcher`, `Adw.ViewStack`: Security page `Adw.StatusPage` + `View Certificate…` `Gtk.Button` `pill`, Permissions page `Adw.PreferencesPage` + `Gtk.ListBox` `content` (permission rows, repeater) | no |
| `src/ephy-certificate-dialog.c` + `.h` | `lib/certificate_dialog.rb` | dialog — `Adw.Dialog` built in C: `Adw.ToolbarView`, `Adw.HeaderBar`, `Adw.Clamp`, `Adw.PreferencesGroup` ×2, `Adw.ActionRow`, `Adw.ButtonRow`, `Gtk.ListBox` `boxed-list`, `Gtk.Grid`, `Gtk.Image`, labels `property` / `monospace`, `Gtk.SizeGroup` | no |
| `src/ephy-privacy-report.c` + `privacy-report.blp` | `lib/privacy_report.rb` | dialog — `Adw.Dialog` > `Adw.NavigationView`: report page with `Adw.ViewSwitcher` + `Adw.ViewStack` (Websites / Trackers `Gtk.ListBox` `boxed-list`, `row-activated`), **empty state** `Adw.StatusPage` `No Trackers Blocked`, Details `Adw.NavigationPage` with `Gtk.ListBox` `boxed-list` | no |
| `lib/ephy-permissions-manager.c` | `lib/permissions_manager.rb` | model | **yes** |
| `embed/ephy-client-certificate-manager.c` | `lib/client_certificate_manager.rb` | dialog — client-certificate / PIN request alerts | no |

### Firefox Sync

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-firefox-sync-dialog.c` + `firefox-sync-dialog.blp` | `lib/firefox_sync_dialog.rb` | window — `Adw.Window` Firefox Sync, sync-now `Adw.ButtonContent`, `Adw.PreferencesPage`: sign-in iframe group, Mozilla Account `Adw.ActionRow` + sign-out, Sync Options (5 `Adw.SwitchRow`, synced-tabs `Gtk.Button`, frequency `Adw.ComboRow`, device-name `Adw.ActionRow` with cancel/save/change `Gtk.Button` + `Gtk.Entry`), `Gtk.SizeGroup` | no |
| `src/synced-tabs-dialog.c` + `synced-tabs-dialog.blp` | `lib/synced_tabs_dialog.rb` | window — `Adw.Window` Synced Tabs, `Gtk.Label`, `Gtk.ScrolledWindow` > `Gtk.ListBox` `boxed-list` | no |
| `lib/ephy-sync-utils.c` | `lib/sync_utils.rb` | helper | **yes** |

### Encoding

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/ephy-encoding-dialog.c` + `encoding-dialog.blp` | `lib/encoding_dialog.rb` | dialog — `Adw.Dialog` Text Encoding, default `Gtk.Switch`, `Gtk.Stack`: suggested box (Recent / Related `Gtk.Label` `heading` + `Gtk.Frame` + `Gtk.ListBox` `row-activated`, `Show All…` `Gtk.Button`) and full list (`Gtk.Frame` > `Gtk.ScrolledWindow` > `Gtk.ListBox`) | no |
| `src/ephy-encoding-row.c` + `encoding-row.blp` | `lib/encoding_row.rb` | row — `Gtk.Box` + `Gtk.Label` + selected `Gtk.Image` `object-select-symbolic` | no |
| `embed/ephy-encoding.c`, `embed/ephy-encodings.c` | `lib/encoding.rb` (class `TextEncoding`), `lib/encodings.rb` (class `TextEncodings`) | model | **yes** (renamed — top-level `Encoding` would reopen Ruby's core class) |

### Web extensions

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `src/webextension/ephy-browser-action-row.c` + `browser-action-row.blp` | `lib/browser_action_row.rb` | row — `Gtk.ListBoxRow` > `Gtk.Box` > `$EphyIndicatorBin` badge + `Gtk.Image` + `Gtk.Label` | no |
| `src/webextension/ephy-indicator-bin.c` | `lib/indicator_bin.rb` | widget — element name `indicatorbin`, `Gtk.Label`, CSS `badge`, `needs-attention`, `numeric` | no |
| `src/webextension/ephy-gizmo.c` | `lib/gizmo.rb` | widget — `Gtk.Widget` layout helper | no |
| `src/webextension/ephy-browser-action.c` | `lib/browser_action.rb` | model | no |
| `src/webextension/ephy-web-extension.c`, `-manager.c` | `lib/web_extension.rb`, `lib/web_extension_manager.rb` | model | no |
| `src/webextension/api/*.c` (11 files) | `lib/web_extension_api/*.rb` | API — alarms, browseraction, commands, cookies, downloads, menus, notifications, pageaction, runtime, storage, tabs, windows; `menus.c` and `notifications.c` are user-facing | no |

### Embed layer (page chrome)

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `embed/ephy-embed.c` + `.h` | `lib/embed.rb` | widget — `Gtk.Box` > `Gtk.Overlay`, `Gtk.GraphicsOffload`, `Gtk.ProgressBar` `osd`, status `Gtk.Label` `end`, `Adw.Banner`, `Gtk.EventControllerMotion` | no |
| `embed/ephy-web-view.c` + `.h` | `lib/web_view.rb` | widget — `WebKit.WebView` subclass; **error states**: invalid TLS certificate, no such file, page crash, network error, process crash, unresponsive process (`Problem Loading Page`, `Oops!`, `This Connection is Not Secure`, `Page Unresponsive`, `Accept Risk and Proceed`, `Force _Stop`), insecure-form banner | no |
| `embed/ephy-find-toolbar.c` + `.h` | `lib/find_toolbar.rb` | toolbar — `Adw.Bin` > `Gtk.SearchBar` + `Adw.Clamp` + `Gtk.Box`, 2 `Gtk.Button`, `Gtk.MenuButton` + `Gtk.PopoverMenu`, `Gtk.EventControllerKey` | no |
| `embed/ephy-search-entry.c` + `.h` | `lib/search_entry.rb` | widget — `Gtk.Widget` with `Gtk.Text` + match-count `Gtk.Label` (`numeric`, `dim-label`), `Gtk.GestureClick` | **yes** |
| `embed/ephy-floating-bar.c` + `.h` | `lib/floating_bar.rb` | widget — `Gtk.Box`, CSS `floating-bar`, `card`; hover-URL overlay | **yes** |
| `embed/ephy-about-handler.c` | `lib/about_handler.rb` | pages — `about:overview`, `about:memory`, `about:applications`, `about:epiphany`, `about:blank` | no |
| `embed/ephy-reader-handler.c` | `lib/reader_handler.rb` | reader-mode renderer | no |
| `embed/ephy-view-source-handler.c` | `lib/view_source_handler.rb` | view-source renderer | no |
| `embed/ephy-embed-autofill.c` | `lib/embed_autofill.rb` | form-autofill popup menu | no |
| `embed/ephy-embed-prefs.c` | `lib/embed_prefs.rb` | settings → WebKit bridge | no |
| `embed/ephy-filters-manager.c` | `lib/filters_manager.rb` | content-filter manager | no |

### Notifications

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `lib/ephy-notification.c` + `.h` | `lib/notification.rb` | widget — `Adw.Bin` > `Gtk.Grid`, 2 `Gtk.Label`, close `Gtk.Button` `flat`; CSS `app-notification` | **yes** |
| `lib/ephy-notification-container.c` + `.h` | `lib/notification_container.rb` | widget — `Adw.Bin` > `Gtk.Revealer` > `Gtk.Box` | **yes** (singleton, as upstream) |

### Non-UI support that components need

| Upstream | → `lib/` | Kind | Exists |
|---|---|---|---|
| `data/org.gnome.epiphany.gschema.xml` + `lib/ephy-settings.c` + `lib/ephy-prefs.h` | `lib/settings.rb` | GSettings — 4 schemas, 103 keys | **yes** |
| `src/resources/style.css`, `style-elementary.css`, `about.css`, `error.css` | `lib/styles.rb` (or `data/`) | stylesheet — the CSS classes above are defined here | partial — `style.css` ported in `lib/styles.rb`; `about.css`, `error.css`, `style-elementary.css` no |
| `src/resources/epiphany.gresource.xml.in` | resource loading in `lib/epiphany/application.rb` | GResource — 37 `.ui`, 4 CSS, 30 icons, `about.ini`, `mask.glsl` | no |
| `po/` (110 languages, 117 POTFILES) | gettext wiring | translations | no |
| `lib/ephy-search-engine-manager.c`, `-engine.c`, `ephy-opensearch-*.c` | `lib/search_engine_manager.rb`, `lib/search_engine.rb`, `lib/opensearch_engine.rb` | model | partial — manager and engine **yes**; `opensearch_engine.rb` no |
| `lib/ephy-snapshot-service.c`, `ephy-favicon-helpers.c` | `lib/snapshot_service.rb`, `lib/favicon_helpers.rb` | thumbnails / favicons | no |
| `lib/ephy-sqlite*.c`, `embed/ephy-history-service*` | `lib/sqlite_connection.rb`, `lib/history_service.rb` | storage | no |
| `src/search-provider/ephy-search-provider.c` | `lib/shell_search_provider.rb` | GNOME Shell search provider | no |
| `src/webapp-provider/ephy-webapp-provider.c` | `lib/webapp_provider.rb` | D-Bus web-app provider | no |
| `src/profile-migrator/ephy-profile-migrator.c` | `lib/profile_migrator.rb` | migration (likely out of scope) | no |

## What exists on `ruby` today

23 files, 4 182 lines. All 21 flat files carry `# frozen_string_literal: true`
and a comment naming the upstream file they came from.

| `lib/*.rb` | Upstream | Kind |
|---|---|---|
| `epiphany/application.rb` | `src/ephy-shell.c`, `src/ephy-main.c` | application — 8 `app.` actions + accels, owns the models |
| `settings.rb` | `data/org.gnome.epiphany.gschema.xml`, `lib/ephy-settings.c` | 4 schemas, 103 keys |
| `styles.rb` | `src/resources/style.css` | stylesheet |
| `shortcuts_dialog.rb` | `src/resources/gtk/shortcuts-dialog.blp` | dialog, 62 items / 6 sections |
| `bookmark.rb`, `bookmarks_manager.rb`, `bookmarks_import.rb`, `bookmarks_export.rb` | `src/bookmarks/ephy-bookmark*.c` | model / import / export |
| `search_engine.rb`, `search_engine_manager.rb` | `lib/ephy-search-engine*.c` | model |
| `permissions_manager.rb` | `lib/ephy-permissions-manager.c` | model |
| `encoding.rb`, `encodings.rb` | `embed/ephy-encoding*.c` | model |
| `suggestion.rb` | `lib/ephy-suggestion.c` | model |
| `sync_utils.rb` | `lib/ephy-sync-utils.c` | helper |
| `notification.rb`, `notification_container.rb` | `lib/ephy-notification*.c` | widget |
| `floating_bar.rb` | `embed/ephy-floating-bar.c` | widget |
| `search_entry.rb` | `embed/ephy-search-entry.c` | widget |
| `link.rb`, `title_widget.rb` | `src/ephy-link.c`, `src/ephy-title-widget.c` | interface mixin |

Everything else in the tables above is missing. The largest single gap is the
window itself (`src/ephy-window.c`: 46 `win.` + 9 `tab.` + 13 `toolbar.` + 33
`popup.` actions) and the toolbar/location-entry cluster it hosts; nothing can
be driven end to end until that lands.

## Notes for the port

- **Repeaters** (one component, N on screen): bookmark rows, history rows,
  download rows, permission rows, search-engine rows, language rows, encoding
  rows, browser-action rows, privacy-report website/tracker rows, WebKit
  feature rows in `prefs-features-page`, suggestion list items.
- **Empty states** are components in their own right: No Bookmarks, No History
  Found, No Results Found (×3 — history, data view, bookmarks search), No
  Trackers Blocked, no-extensions card, `data-view` empty/no-results pages.
- **Error states** live in `embed/ephy-web-view.c` (6 error kinds) and
  `window-commands.c` (4 `Adw.AlertDialog`s, 4 `Adw.Toast`s).
- **Dynamic CSS on the window**: `narrow`, `incognito-mode`, `devel`,
  `automation-mode` — all four must be reproduced.
- `clear-data-view` and `passwords-view` subclass `$EphyDataView`, so
  `lib/data_view.rb` must be a real base class, not a copy per view.
- `location-entry.blp` and `action-bar*.blp` both instantiate
  `$EphySiteMenuButton`; it is one component used in three places.
