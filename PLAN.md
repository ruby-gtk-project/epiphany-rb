# Round scope

Tracked here, before the round's commits, so scope narrowing is a decision
made up front rather than a comment written into the commit that narrows it.

## This round (round 2)

In scope, and landed:

- `app.new-window`, `app.reopen-closed-tab`, `app.run-in-background`,
  `app.about` — the four page-menu actions this round installs for real,
  each exercised by `test/drive_epiphany.rb` through the actual `Gio`
  action, not just the `Window`/`Application` method behind it.
- `toolbar.navigation-back` / `toolbar.navigation-forward`: already synced
  to `Page#can_go_back?`/`#can_go_forward?` from a previous round, but not
  exercised as real actions by the drive script; this round's drive script
  now activates them directly and asserts on the resulting address and
  enabled state.
- Verified the four mandated binding gems (`ashpd`, `gcr-rb`, `soup3`,
  `webkit-web-process-extension`) still load and are each required and
  genuinely called from `lib/`; no regression found.

Explicitly out of scope this round (left in `remaining`, not stubbed):

- `app.new-incognito`, `app.history`, `win.privacy-report`, `win.passwords`,
  `app.preferences` — each needs a real model or dialog (an incognito
  profile, a history store, a passwords/Secret Service integration, a
  multi-page preferences dialog) too large to land honestly alongside the
  above in one round.
- The WebKitWebView/EphyEmbed layer (`embed/ephy-embed.c`,
  `src/ephy-location-entry.c`, location controller, suggestion model): tabs
  still render as `Adwaita::StatusPage` placeholders with a history stack,
  not a real web view. This is the single biggest remaining parity gap and
  is sequenced for a dedicated round of its own (it is a prerequisite for
  the location bar, downloads popover content, and most of the dialogs
  below).
- DownloadsPopover and BookmarksDialog (or stand-ins) behind the two
  downloads buttons and the bookmarks toggle.
- All of: bookmarks/history/downloads/certificate/privacy/preferences/
  encoding/sync/web-extension *dialogs* (as opposed to the models backing
  some of them, several of which are already ported).
- gettext-equivalent i18n: no `_()` wrapping exists yet anywhere in the
  port; every string across every round is still a hardcoded literal.
- `rake spec` / `kettle-test` resolving inside the nix devshell, and any
  ported `spec/*_spec.rb` files.

## Sequencing rationale

Models and backends before the widgets that show them; the window before
the dialogs it opens. The embed layer is the dependency root for the
location bar and most of the remaining dialogs, so it is next, as its own
round, before dialog work that would otherwise sit on a placeholder page
with no real navigation underneath it.
