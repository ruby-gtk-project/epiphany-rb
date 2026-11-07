# Component parity — epiphany-rb vs origin/main

Adversarial check: for every upstream component, does the port build the same
widget, in the same count, with the same CSS classes, the same signals/actions,
and the same translatable text? Verdict per component area below; "gap" means
the axis cannot even be evaluated because the component does not exist.

This revision updates the base report for what changed this round
(`download.rb`, `downloads_manager.rb`, `mouse_gesture_controller.rb`) and
corrects one number the prior report got wrong (see below). Every section not
mentioned as changed is unchanged from the base audit, re-verified by reading
the current `lib/` tree and `origin/main` directly rather than trusting the
prior text.

## Application shell (`lib/epiphany/application.rb` ← `ephy-shell.c` + `ephy-main.c`)

- **Count**: upstream installs 21 `app.` actions with accelerators. Reading
  `lib/epiphany/application.rb` directly: the port installs **2**
  (`shortcuts`, `quit`) — not 8, which is what the prior round's
  `component-identification.md` claimed. Correcting that number here and in
  `component-identification.md`. 19 of 21 `app.` actions are gap, including
  `app.preferences` and `app.about`.
- **Style**: n/a — no dialogs to carry CSS classes for the missing 19.
- **Behaviour**: the 2 that exist match upstream's accelerators. The missing
  19 are not stubbed; pressing their shortcuts does nothing.
- **Text**: n/a for the missing actions.
- **Verdict: gap — 19 of 21 `app.` actions missing** (worse than previously
  reported, because the previous count was wrong, not because anything
  regressed).

## Main window (`ephy-window.c` → `lib/window.rb`)

Unchanged from the base audit. `lib/window.rb` does not exist.
`Epiphany::Application#build` still shows a bare `Adw.StatusPage`
(`status_page`, confirmed by reading the current file) in place of the
window's real content, and its own description string says so plainly: "The
browsing window is not written yet." `window_action_groups` creates four
empty `Gio::SimpleActionGroup`s (`win`, `toolbar`, `tab`, `popup`) as
placeholders with zero actions in any of them — confirmed by reading
`lib/epiphany/application.rb:121`. **Verdict: gap, total.** 0 of 101
window-level actions exist (46 `win.` + 9 `tab.` + 13 `toolbar.` + 33
`popup.`). No tab strip, split view, toast-overlay content, or
password-generator popover.

## Mouse gestures (new this round)

- Upstream: `src/ephy-mouse-gesture-controller.c` attaches a `GtkGestureDrag`
  to the real window in the capture phase, restricted to the middle button
  and to drags that begin over the web view.
- Port: `lib/mouse_gesture_controller.rb` reimplements the direction-guessing
  and action-activation logic against a `window_adapter` Struct
  (`widget`/`action_group`) standing in for the real window, since there is
  no web view to restrict the gesture-start check to and no real window to
  attach to. Exercised by the drive script's single-stroke/two-stroke steps.
- **Count**: logic ported 1:1 for the gesture-recognition algorithm.
  **Behaviour caveat**: upstream's gesture only claims the sequence when it
  starts over the web view widget, specifically to leave page text-selection
  alone; the port has no web view to check against, so this constraint is
  unverifiable until `lib/web_view.rb` exists. Flagging this rather than
  calling it "ported": it is ported code with an unverifiable precondition.
- **Verdict: partial.** Real logic, but untestable against its one upstream
  safety constraint because the thing that constraint protects doesn't
  exist in the port.

## Downloads (new this round, partially)

- `lib/download.rb`, `lib/downloads_manager.rb`: ported as in-process models
  (uid counter, action enum, destination handling) exercised by the drive
  script.
- `downloads_popover.rb`, `download_widget.rb`, `downloads_paintable.rb`:
  **still none exist.** No download can be shown or managed through any
  widget; the models exist with nothing rendering them.
- **Verdict: gap, UI entirely** (model layer now has a real candidate — the
  one upgrade this round makes to this section versus the base report, which
  previously listed "none exist" for the whole group including the model).

## Toolbars and location entry

Unchanged, confirmed by re-listing `lib/`: `action_bar*.rb`,
`location_entry.rb`, `location_controller.rb`, `suggestion_model.rb`,
`page_menu_button.rb`, `site_menu_button.rb` — **none exist.** No address
bar. **Verdict: gap, total.**

## Bookmarks

Unchanged. Model layer ported and exercised; UI layer
(`bookmarks_dialog.rb`, `bookmark_row.rb`, `bookmark_properties.rb`) — none
exist. **Verdict: model has parity-eligible candidates; UI total gap.**

## History

Unchanged. Neither dialog nor model/service exists. **Verdict: gap, total.**

## Preferences (6 pages + dialog + supporting rows/dialogs)

Unchanged — confirmed `app.preferences` is still not one of the 2 actions
that exist (it would need to be among the missing 19). **Verdict: gap,
total**, and now there isn't even an action binding to open it.

## Data views, security/privacy, Firefox Sync, encoding UI, web extensions,
## embed layer

Unchanged from the base report; re-confirmed none of these files exist in
`lib/`. `permissions_manager.rb`, `sync_utils.rb`, `encoding.rb`/
`encodings.rb` model layers remain the only real candidates; no UI for any
of them.

## Notifications

Unchanged, still a genuinely strong area: `notification.rb` +
`notification_container.rb` exist and are exercised.

## Non-UI support

Unchanged except `downloads_manager.rb` is no longer "none exist" (see
Downloads above). GResource bundle, icons, `po/` wiring, search provider,
web-app provider, snapshot/favicon services, SQLite/history storage: still
all absent.

## Summary verdict

**Not clean.** Of roughly 82 distinct upstream UI component files, the port
has shipped UI for **zero** of them — still true after this round's
additions, which are both model/controller classes with no widget tree. The
one number that moved against the port rather than for it: the `app.`
action count is 2, not the 8 a prior report claimed — a correction, not a
regression, but it means the gap on that axis is wider than this repo's own
documentation previously said. No empty state and no error state listed in
the upstream inventory exists in the port.
