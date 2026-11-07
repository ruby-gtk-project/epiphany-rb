# epiphany-rb drive report

Date: 2026-11-07

## Drive script

`test/drive_epiphany.rb` (plus `test/gtk_driver.rb`, already present) builds the
real `Epiphany::Application`, activates it, and drives every component this
round of the port landed:

- the application window, header bar, menu button + page menu, status page
- bookmarks manager (add/find/tag/remove)
- search engine manager (defaults, custom engine, bang parsing)
- permissions manager
- download + downloads manager
- mouse gesture controller
- text encodings (database) and TextEncoding (title eliding, language groups)
- sync utils (hex/base64 round trip)
- link flags, suggestion
- bookmarks export/import round trip (native JSON, HTML, and the
  missing-file error path)
- OpenSearch autodiscovery link + OpensearchEngine XML parsing (success and
  the no-search-terms rejection path)
- notification + notification container (show, dedupe, hide-when-empty)
- floating bar
- search entry (match counter, clear icon, activate -> next-match)
- title widget security mixin
- the shortcuts dialog, opened through the real `app.shortcuts` action
- the real `app.quit` action, asserted to persist window geometry

65 of 65 checks pass, zero Gtk-CRITICAL warnings, screenshots written under
`tmp/shots/`. Fixed one test bug found while driving: the script was calling
`Notification#build` itself before `show`, when `NotificationContainer#append`
already builds the notification — the double build re-attached already
-parented widgets into the grid and tripped a
`gtk_grid_attach: assertion '_gtk_widget_get_parent (child) == NULL' failed`
warning. Not a port bug; fixed in the test.

Not yet portable to the drive script because the port hasn't built them yet:
the browsing window / tabs, the browser action bar, bookmarks UI, history,
preferences, downloads popover, password manager UI, sync UI. The app's own
status page says as much ("the browsing window is not written yet"), so this
drive covers everything the port currently claims to have.

## Spec suite

The dev-shell banner's documented spec command:

```
ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

fails before any example runs:

```
Failure/Error: require "kettle/test/rspec"
LoadError:
  cannot load such file -- kettle/test/rspec
```

`epiphany-rb.gemspec` development-depends on `kettle-test` (~> 2.0, >= 2.0.29)
and `kettle-dev`, but neither is resolvable in this sandbox (no
`Gemfile.lock`, no network to fetch them, and `bundle show kettle-test`
reports "Could not find gem"). This is a missing dev-dependency gem in the
offline Nix environment, not a GObject/ruby-gnome binding gap and not a bug
in the ported widget code — `spec/` currently contains only `spec_helper.rb`
with no example files, so even a successful load would run 0 examples. Left
failing; not worked around.
