# Component inventory — epiphany-rb (`ruby` vs upstream `origin/main`)

Survey only. No app code was written for this pass. Upstream read via
`git show origin/main:<path>` / `git ls-tree -r --name-only origin/main`
(688 tracked paths). Current `lib/` has 29 files plus the `epiphany/`
app-shell namespace.

## Gem wiring check (per task instructions)

All four mandatory gems are already wired and actually exercised on the live
code path — no regression found, nothing to fix:

| Gem | Namespace | `spec.add_dependency` | `require` site | Live call |
|---|---|---|---|---|
| `ashpd` | `Ashpd` | yes | `lib/download.rb` | `Ashpd::OpenUri.open` |
| `gcr-rb` | `Gcr` / `Gck` | yes | `lib/certificate.rb` | `Gcr::SimpleCertificate.new` |
| `soup3` | `Soup` | yes | `lib/opensearch_engine.rb`, `lib/search_engine.rb` | `Soup::Message.new` / `Soup::Session.new` |
| `webkit-web-process-extension` | `WebKitWebProcessExtension` | yes | `lib/web_process_extension.rb` | `WebKitWebProcessExtension::UserMessage.new`, `#send_message_to_view` |

`gtk4`, `adwaita`, `glib2`, `rexml` are also declared and used. Nothing in the
gemspec is undeclared-but-required or declared-but-unused.

## Scope of this inventory

Per the task, only user-facing surfaces: windows, dialogs, pages, rows, menus,
keyboard shortcuts, preferences, actions, empty/error states, plus their
`.blp`/`.ui` files, the GSettings schema, the GResource manifest, and `po/`.
Upstream's non-UI backend (`lib/ephy-sqlite*`, `lib/ephy-zoom.c`,
`lib/history/*`, `lib/sync/*` crypto/manager plumbing, `embed/` browsing
engine internals, `src/profile-migrator/`, `src/search-provider/`,
`src/webapp-provider/`) is out of scope here and not listed row-by-row, except
where it backs a listed widget (noted inline).

Legend: ✅ exists in `lib/` · ❌ missing · 🟡 partial (model/util ported, the
widget/dialog around it is not).

## 1. Application shell & main window

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/ephy-main.c`, `src/ephy-shell.c` | `lib/epiphany/application.rb` | app/shell | 🟡 — app object, actions for `shortcuts`/`quit` only, startup/activate wiring present; shell's tab/window/session management not ported |
| `src/ephy-window.c` | `lib/window.rb` | window | ❌ — the whole browser window (toolbar, tab view, find bar, security button, menus) does not exist yet; `Application#build` currently shows a placeholder status page instead |
| `src/ephy-header-bar.c` | `lib/header_bar.rb` | widget (header bar) | ❌ |
| `src/ephy-title-box.c` | `lib/title_box.rb` | widget | ❌ |
| `src/ephy-title-widget.c` | `lib/title_widget.rb` | widget | ✅ |
| `src/ephy-action-bar.c` | `lib/action_bar.rb` | widget | ❌ |
| `src/ephy-action-bar-start.c` + `src/resources/gtk/action-bar-start.blp` | `lib/action_bar_start.rb` | widget | ❌ |
| `src/ephy-action-bar-end.c` + `src/resources/gtk/action-bar-end.blp` | `lib/action_bar_end.rb` | widget | ❌ |
| `src/resources/gtk/action-bar.blp` | (part of `action_bar.rb`) | template | ❌ |
| `src/ephy-action-helper.c` | `lib/action_helper.rb` | helper (actions) | ❌ |
| `src/ephy-tab-view.c` | `lib/tab_view.rb` | widget | ❌ |
| `src/resources/gtk/tab-overview-menu.blp` | `lib/tab_overview_menu.rb` | menu (no backing `.c`) | ❌ |
| `src/resources/gtk/notebook-context-menu.blp` | `lib/notebook_context_menu.rb` | menu (no backing `.c`) | ❌ |
| `src/context-menu-commands.c` | `lib/context_menu_commands.rb` | actions | ❌ |
| `src/window-commands.c` | `lib/window_commands.rb` | actions | ❌ |
| `src/ephy-fullscreen-box.c` | `lib/fullscreen_box.rb` | widget | ❌ |
| `src/ephy-page-menu-button.c` + `src/resources/gtk/page-menu-button.blp` | `lib/page_menu_button.rb` | widget (menu button) | ❌ |
| `src/ephy-site-menu-button.c` + `src/resources/gtk/site-menu-button.blp` | `lib/site_menu_button.rb` | widget (menu button) | ❌ |
| `src/ephy-location-controller.c` | `lib/location_controller.rb` | controller | ❌ |
| `src/ephy-location-entry.c` + `src/resources/gtk/location-entry.blp` | `lib/location_entry.rb` | widget (address bar) | ❌ — depends on `lib/search_entry.rb` (✅) and `lib/suggestion.rb` (✅), which already exist |
| `src/ephy-suggestion-model.c` | `lib/suggestion_model.rb` | model backing address-bar popover | ❌ |
| `embed/ephy-search-entry.c` | `lib/search_entry.rb` | widget | ✅ |
| `embed/ephy-floating-bar.c` | `lib/floating_bar.rb` | widget | ✅ |
| `lib/contrib/dzl-suggestion.c` (vendored) | `lib/suggestion.rb` | model | ✅ |
| `src/ephy-link.c` | `lib/link.rb` | interface/mixin | ✅ |
| `src/ephy-mouse-gesture-controller.c` | `lib/mouse_gesture_controller.rb` | controller | ✅ |
| `src/ephy-desktop-utils.c` | — | util, not a widget | n/a (out of scope) |
| `src/ephy-lockdown.c` | `lib/lockdown.rb` | policy (hides/disables menu items per GSettings lockdown keys) | ❌ |
| `src/ephy-session.c` | `lib/session.rb` | session save/restore (crash-restore dialog UX) | ❌ |

## 2. Bookmarks

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/bookmarks/ephy-bookmark.c` | `lib/bookmark.rb` | model | ✅ |
| `src/bookmarks/ephy-bookmarks-manager.c` | `lib/bookmarks_manager.rb` | manager/model | ✅ |
| `src/bookmarks/ephy-bookmarks-export.c` | `lib/bookmarks_export.rb` | action | ✅ |
| `src/bookmarks/ephy-bookmarks-import.c` | `lib/bookmarks_import.rb` | action | ✅ |
| `src/bookmarks/ephy-bookmarks-dialog.c` + `src/resources/gtk/bookmarks-dialog.blp` | `lib/bookmarks_dialog.rb` | dialog | ❌ |
| `src/bookmarks/ephy-bookmark-row.c` + `src/resources/gtk/bookmark-row.blp` | `lib/bookmark_row.rb` | row | ❌ |
| `src/bookmarks/ephy-bookmark-properties.c` + `src/resources/gtk/bookmark-properties.blp` | `lib/bookmark_properties.rb` | dialog | ❌ |
| `src/resources/gtk/browser-action-row.blp` | `lib/browser_action_row.rb` (webextension, see §6) | row | ❌ |

## 3. History

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/ephy-history-dialog.c` + `src/resources/gtk/history-dialog.blp` | `lib/history_dialog.rb` | dialog | ❌ |
| `src/ephy-history-dialog-row.c` | `lib/history_dialog_row.rb` | row | ❌ |
| `lib/history/ephy-history-service.c` et al. | (backend, out of scope) | service | n/a |

## 4. Downloads

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/ephy-download-widget.c` | `lib/download_widget.rb` | widget (row in downloads popover) | ❌ — `lib/download.rb` (✅) is the model, the widget wrapping it is missing |
| `src/ephy-downloads-popover.c` | `lib/downloads_popover.rb` | popover | ❌ |
| `src/ephy-downloads-paintable.c` | `lib/downloads_paintable.rb` | paintable (toolbar icon progress) | ❌ |
| (manager) | `lib/downloads_manager.rb` | manager/model | ✅ |

## 5. Security / certificates / privacy

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/ephy-certificate-dialog.c` + implied `.blp` | `lib/certificate_dialog.rb` | dialog | ❌ — `lib/certificate.rb` (✅) is the `Gcr`-backed model only |
| `src/ephy-security-dialog.c` + `src/resources/gtk/security-dialog.blp` | `lib/security_dialog.rb` | dialog | ❌ |
| `src/ephy-privacy-report.c` + `src/resources/gtk/privacy-report.blp` | `lib/privacy_report.rb` | dialog | ❌ |
| `embed/ephy-client-certificate-manager.c` | `lib/client_certificate_manager.rb` | manager | ❌ |
| `lib/ephy-permissions-manager.c` | `lib/permissions_manager.rb` | manager/model | ✅ |
| `src/preferences/clear-data-view.c` + `.blp` | `lib/clear_data_view.rb` | preferences view | ❌ |

## 6. Encoding

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `lib/ephy-output-encoding.c` (upstream's `lib/`) | `lib/encoding.rb`, `lib/encodings.rb` | model | ✅ |
| `src/ephy-encoding-dialog.c` + `src/resources/gtk/encoding-dialog.blp` | `lib/encoding_dialog.rb` | dialog | ❌ |
| `src/ephy-encoding-row.c` + `src/resources/gtk/encoding-row.blp` | `lib/encoding_row.rb` | row | ❌ |

## 7. Search engines / address-bar suggestions

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `lib/ephy-search-engine.c`, `lib/ephy-search-engine-manager.c` | `lib/search_engine.rb`, `lib/search_engine_manager.rb` | model | ✅ |
| `lib/ephy-opensearch-engine.c`, `lib/ephy-opensearch-autodiscovery-link.c` | `lib/opensearch_engine.rb`, `lib/opensearch_autodiscovery_link.rb` | model | ✅ |
| `src/preferences/ephy-search-engine-listbox.c` + `.blp` | `lib/search_engine_listbox.rb` | listbox (preferences) | ❌ |
| `src/preferences/ephy-search-engine-row.c` + `.blp` | `lib/search_engine_row.rb` | row | ❌ |
| `src/preferences/prefs-search-engine-page.c` + `.blp` | `lib/prefs_search_engine_page.rb` | preferences page | ❌ |

## 8. Preferences dialog (`Adw.PreferencesDialog`)

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/preferences/ephy-prefs-dialog.c` + `src/resources/gtk/prefs-dialog.blp` | `lib/prefs_dialog.rb` | dialog | ❌ |
| `src/preferences/prefs-general-page.c` + `.blp` | `lib/prefs_general_page.rb` | preferences page | ❌ |
| `src/preferences/prefs-appearance-page.c` + `.blp` | `lib/prefs_appearance_page.rb` | preferences page | ❌ |
| `src/preferences/prefs-privacy-page.c` + `.blp` | `lib/prefs_privacy_page.rb` | preferences page | ❌ |
| `src/preferences/prefs-extensions-page.c` + `.blp` | `lib/prefs_extensions_page.rb` | preferences page | ❌ |
| `src/preferences/prefs-features-page.c` + `.blp` | `lib/prefs_features_page.rb` | preferences page | ❌ |
| `src/preferences/ephy-data-view.c` + `src/resources/gtk/data-view.blp` | `lib/data_view.rb` | preferences sub-view | ❌ |
| `src/preferences/autofill-view.c` + `.blp` | `lib/autofill_view.rb` | preferences sub-view | ❌ |
| `src/preferences/extension-view.c` + `.blp` | `lib/extension_view.rb` | preferences sub-view | ❌ |
| `src/preferences/ephy-lang-row.c` + `src/resources/gtk/lang-row.blp` + `prefs-lang-dialog.blp` | `lib/lang_row.rb`, `lib/prefs_lang_dialog.rb` | row + dialog | ❌ |
| `src/preferences/ephy-passwords-view.c` (listed under `src/`, not `src/preferences/`) | `lib/passwords_view.rb` | preferences sub-view | ❌ |
| `src/preferences/webapp-additional-urls-dialog.c` + `.blp` | `lib/webapp_additional_urls_dialog.rb` | dialog | ❌ |

## 9. Sync

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `lib/ephy-sync-utils.c` (upstream's `lib/`) | `lib/sync_utils.rb` | util/model | ✅ |
| `src/ephy-firefox-sync-dialog.c` + `src/resources/gtk/firefox-sync-dialog.blp` | `lib/firefox_sync_dialog.rb` | dialog | ❌ |
| `src/synced-tabs-dialog.c` + `src/resources/gtk/synced-tabs-dialog.blp` | `lib/synced_tabs_dialog.rb` | dialog | ❌ |

## 10. Notifications

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `lib/ephy-notification.c` | `lib/notification.rb` | model | ✅ |
| `lib/ephy-notification-container.c` | `lib/notification_container.rb` | widget | ✅ |

## 11. Web extensions (WebExtensions API support)

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/webextension/ephy-web-extension.c` | `lib/web_extension.rb` | model | ❌ |
| `src/webextension/ephy-web-extension-manager.c` | `lib/web_extension_manager.rb` | manager | ❌ |
| `src/webextension/ephy-browser-action.c` | `lib/browser_action.rb` | popover/widget | ❌ |
| `src/webextension/ephy-browser-action-row.c` + `src/resources/gtk/browser-action-row.blp` | `lib/browser_action_row.rb` | row | ❌ |
| `src/webextension/ephy-indicator-bin.c` | `lib/indicator_bin.rb` | widget (toolbar indicator) | ❌ |
| `src/webextension/ephy-gizmo.c` | `lib/gizmo.rb` | small helper widget | ❌ |
| `embed/web-process-extension/ephy-web-process-extension.c` | `lib/web_process_extension.rb` | web-process bridge | ✅ (uses `WebKitWebProcessExtension` gem live) |

`src/webextension/api/*.c` (alarms, browseraction, commands, cookies,
downloads, menus, notifications, pageaction, runtime, storage, tabs, windows)
are the WebExtensions JS-API backends, not independently user-visible; out of
scope here.

## 12. Shortcuts / standalone menus (no backing `.c`)

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/resources/gtk/shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | dialog (shortcuts window) | ✅ |

## 13. Styling, GSettings, GResource, locale

| Upstream | → `lib/` | Kind | Exists? |
|---|---|---|---|
| `src/resources/style.css`, `style-elementary.css`, `about.css`, `error.css` | `lib/styles.rb` | stylesheet loader | ✅ (loads/applies CSS; confirm it covers all four stylesheets, not just `style.css`) |
| `src/resources/about.ini`, `about.html`-equivalent, `error.html` | — | static content pages | ❌ (no equivalent error/about page widget yet) |
| `data/org.gnome.epiphany.gschema.xml` | `lib/settings.rb` | GSettings schema wrapper | ✅ — confirm every key the ported widgets read/write (lockdown keys, search-engine keys, sync keys) is present; widgets not yet ported will need their keys added as they land |
| `src/resources/epiphany.gresource.xml.in` | (bundled assets — icons, CSS, `.ui` compiled from `.blp`) | GResource manifest | n/a — Ruby port has no GResource step; assets are loaded directly. Not yet inventoried whether every SVG icon under `src/resources/*.svg` has a Ruby-side equivalent (icon theme lookup) |
| `data/org.gnome.Epiphany.desktop.in.in`, `.metainfo.xml.in.in` | — | app metadata | ❌ not ported (needed for packaging, not strictly a widget) |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` | — | translation catalogue | ❌ — no `po/` or gettext wiring found under `ruby`; translation-parity is a separate skill/pass |

## Totals

- Upstream user-facing `.c`/`.h` component files surveyed: ~95 (src/, src/preferences/, src/bookmarks/, src/webextension/, embed/ UI-adjacent files), plus 33 `.blp` templates and 2 standalone menu `.blp`s.
- Currently ported (`✅`) in `lib/`: 29 files, almost entirely **models and
  controllers** (settings, bookmarks data, search engines, encodings,
  permissions, sync utils, notifications-model, suggestion model, link
  interface, mouse-gesture controller) plus a few already-widget-level pieces
  (`floating_bar.rb`, `search_entry.rb`, `title_widget.rb`,
  `notification_container.rb`, `shortcuts_dialog.rb`).
- **Not yet ported**: the entire window/chrome layer — `ephy-window.c`,
  header bar, action bars, tab view, location entry/controller, every dialog
  (bookmarks, history, preferences × 10 pages, certificate/security/privacy,
  sync, encoding), every row type, the webextension UI layer, and the
  app-metadata/po/GResource-adjacent assets.
- This matches `lib/epiphany/application.rb`'s own comment: the window and
  browsing stack are explicitly not ported yet, and the current window
  content is a placeholder status page.

## Suggested next units (smallest, most self-contained first)

1. `src/ephy-encoding-row.c` + `lib/encodings.rb` (already have model) → `lib/encoding_row.rb`, then `lib/encoding_dialog.rb`.
2. `src/bookmarks/ephy-bookmark-row.c` (model already ported) → `lib/bookmark_row.rb`, then `lib/bookmarks_dialog.rb`.
3. `src/ephy-download-widget.c` (model already ported) → `lib/download_widget.rb`, then `lib/downloads_popover.rb`.
4. `src/ephy-header-bar.c` / action bars / `ephy-window.c` — the big one that unblocks everything downstream; do last, in sub-slices (title box → action bars → header bar → window shell).
