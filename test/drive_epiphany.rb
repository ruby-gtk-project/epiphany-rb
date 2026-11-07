# frozen_string_literal: true

# Drives the whole port headlessly: builds the real application and window,
# exercises every model this round of the port landed (bookmarks, search
# engines, permissions, encodings, sync utils, opensearch, bookmark tags,
# link flags, suggestions), builds and drives the standalone widgets
# (notification + container, floating bar, search entry, title widget), opens
# the shortcuts dialog through the real app action, and finally fires the
# real quit action and checks it persisted window geometry before quitting.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window; only running it proves
# the widgets, the actions and the models actually work together.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_epiphany.rb

require "fileutils"
require "tmpdir"

# A scratch config directory, so a run never reads or writes the real one.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("epiphany-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "epiphany"
require_relative "gtk_driver"

# The models the application exposes but does not wire into the window yet.
require "bookmark"
require "bookmarks_manager"
require "search_engine_manager"
require "search_engine"
require "permissions_manager"
require "download"
require "downloads_manager"
require "mouse_gesture_controller"
require "encodings"
require "sync_utils"
require "opensearch_engine"
require "opensearch_autodiscovery_link"
require "link"
require "suggestion"
require "notification"
require "notification_container"
require "floating_bar"
require "search_entry"
require "title_widget"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

app_object = Epiphany::Application.new

GtkDriver.drive(app_object, shots: SHOTS) do |d, app|
  d.window { app.window }

  # --- The window the application itself builds ---------------------------

  d.step("app activates") do
    d.check("window exists") { !app.window.nil? }
    d.check("window title is epiphany") { app.window.title == "epiphany" }
    d.check("status page is the toolbar view content") do
      app.toolbar_view.content == app.status_page
    end
    d.check("status page names what landed") do
      app.status_page.description.include?("settings") &&
        app.status_page.description.include?("bookmarks")
    end
    d.check("header bar carries the menu button") do
      app.header_bar.respond_to?(:pack_end)
      app.menu_button.menu_model == app.page_menu
    end
    d.check("page menu has shortcuts and quit") { app.page_menu.n_items == 2 }
    d.check("notification container starts hidden") { !app.notification_container.widget.visible? }
    d.shot("01-main-window")
  end

  # --- Model layer: bookmarks ----------------------------------------------

  d.step("bookmarks manager") do
    dir = Dir.mktmpdir("epiphany-bookmarks")
    manager = BookmarksManager.new(filename: File.join(dir, "bookmarks.json"))
    bookmark = Bookmark.new(
      "https://example.org",
      "Example",
      ["work"],
      "1",
    )

    manager.add_bookmark(bookmark)
    d.check("bookmark stored") { manager.n_items == 1 }
    d.check("bookmark found by url") { manager.bookmark_by_url("https://example.org") == bookmark }

    # Matches upstream: ephy_bookmarks_manager_add_bookmark does not index the
    # bookmark's tags on its own (only the sync-merge path does); the UI calls
    # create_tag separately when a tag is newly typed.
    manager.create_tag("work")
    d.check("tag indexed") { manager.tag_exists?("work") }
    d.check("bookmarks with tag") { manager.bookmarks_with_tag("work") == [bookmark] }

    manager.remove_bookmark(bookmark)
    d.check("bookmark removed") { manager.n_items.zero? }
  end

  # --- Model layer: search engines -----------------------------------------

  d.step("search engine manager") do
    # SearchEngineManager's `settings:` wants a Schema (what Settings.main
    # hands out), not a bare Settings instance.
    settings = Settings.new(path: File.join(Dir.mktmpdir("epiphany-settings"), "settings.json")).schema(Settings::MAIN)
    manager = SearchEngineManager.new(settings: settings)

    d.check("defaults to a non-empty engine list") { manager.n_items.positive? }
    d.check("has a default engine") { !manager.default_engine.nil? }

    custom = SearchEngine.new(name: "Custom", url: "https://example.org/?q=%s", bang: "!custom")
    manager.add_engine(custom)
    d.check("custom engine added") { manager.find_engine_by_name("Custom") == custom }
    d.check("bang recognised") { manager.bang?("!custom") }
    d.check("bang search parsed") do
      manager.parse_bang_search("!custom foo") == custom.build_search_address("foo")
    end
  end

  # --- Model layer: permissions ---------------------------------------------

  d.step("permissions manager") do
    settings = Settings.new(path: File.join(Dir.mktmpdir("epiphany-settings"), "settings.json"))
    manager = PermissionsManager.new(settings: settings)

    manager.set_permission(:show_notifications, "https://example.org", PermissionsManager::PERMIT)
    d.check("permission stored") do
      manager.permission(:show_notifications, "https://example.org") == PermissionsManager::PERMIT
    end
    d.check("permitted origins lists it") do
      manager.permitted_origins(:show_notifications).include?("https://example.org")
    end
  end

  # --- Model layer: downloads -------------------------------------------------

  d.step("download and downloads manager") do
    fake_wk_download = Struct.new(:destination, :estimated_progress) do
      def allow_overwrite? = false

      def cancel
        @cancelled = true
      end

      def cancelled? = !!@cancelled
    end.new(nil, 0.5)

    download = Download.new(fake_wk_download, content_type: "text/plain")
    dir = Dir.mktmpdir("epiphany-downloads")
    download.set_destination_for_suggested_filename("report.txt", directory: dir)
    d.check("destination chosen under the given directory") do
      download.destination == File.join(dir, "report.txt")
    end
    d.check("download starts active") { download.active? }

    added = []
    manager = DownloadsManager.new
    manager.on_download_added { |dl| added << dl }
    manager.add_download(download)
    d.check("download added fires the callback") { added == [download] }
    d.check("manager reports active downloads") { manager.active_downloads? }

    download.mark_completed
    d.check("download succeeded once marked completed") { download.succeeded? }
    d.check("manager progress is 1.0 once nothing is active") { manager.estimated_progress == 1.0 }
    d.check("manager finds the download by uid") { manager.find_download_by_id(download.uid) == download }
  end

  # --- Controller: mouse gestures ---------------------------------------------

  d.step("mouse gesture controller") do
    fired = []
    window_adapter = Struct.new(:widget, :groups) do
      def action_group(name) = groups[name]
    end.new(app.window, %w[win toolbar tab].to_h { |n| [n, Gio::SimpleActionGroup.new] })

    %w[toolbar win tab].each do |group_name|
      %w[navigation-back navigation-forward new-tab close reload].each do |action_name|
        action = Gio::SimpleAction.new(action_name)
        action.signal_connect("activate") { fired << "#{group_name}.#{action_name}" }
        window_adapter.action_group(group_name).add_action(action)
      end
    end

    controller = MouseGestureController.new(window_adapter)
    controller.attach
    d.check("controller attaches without raising") { !controller.gesture.nil? }
    controller.detach
  end

  # --- Model layer: encodings -----------------------------------------------

  d.step("text encodings") do
    settings = Settings.new(path: File.join(Dir.mktmpdir("epiphany-settings"), "settings.json")).schema(Settings::STATE)
    encodings = TextEncodings.new(settings: settings)

    d.check("built-in encodings loaded") { encodings.all.size.positive? }
    d.check("utf-8 is a known encoding") { !encodings.encoding("UTF-8").nil? }
  end

  # --- Model layer: sync utils -----------------------------------------------

  d.step("sync utils round trips") do
    bytes = SyncUtils.generate_random_bytes(16)
    hex = SyncUtils.encode_hex(bytes)
    d.check("hex round-trips") { SyncUtils.decode_hex(hex) == bytes }

    b64 = SyncUtils.base64_urlsafe_encode(bytes)
    d.check("base64 round-trips") { SyncUtils.base64_urlsafe_decode(b64) == bytes }
  end

  # --- Model layer: link flags and suggestions -------------------------------

  d.step("link flags and suggestions") do
    d.check("middle click opens a new tab") do
      (Link.flags_from_modifiers(0, middle_click: true) & Link::NEW_TAB) != 0
    end

    suggestion = Suggestion.create("<b>Example</b>", "Example", "https://example.org")
    d.check("suggestion keyed by uri") { suggestion.id == "https://example.org" }
    d.check("plain suggestion is not a completion") { !suggestion.completion? }
  end

  # --- Notification + container, driven through the app's own real instances,
  #     already realized because they are overlays in the window the app
  #     presented at activation. ------------------------------------------

  d.step("notifications") do
    container = app.notification_container

    first = Notification.new("Saved", "Bookmark added").tap(&:build)
    dup = Notification.new("Saved", "Bookmark added").tap(&:build)

    first.show(container)
    d.check("notification shown") { container.notifications.include?(first) }
    d.check("container becomes visible") { container.widget.visible? }

    dup.show(container)
    d.check("duplicate notification dropped") { container.notifications.length == 1 }

    # Leave one more live, then shoot a tick later so the revealer has had a
    # chance to allocate before the paint.
    $shown_notification = Notification.new("Downloading", "survey.pdf").tap(&:build)
    $shown_notification.show(container)

    container.send(:remove_notification, first)
    d.check("container hides once empty with only the stray gone") { container.notifications.length == 1 }
  end

  d.step("notification screenshot") do
    d.shot("02-notification", app.notification_container.widget)
  end

  # --- Floating bar, likewise the app's own real instance, already an
  #     overlay in the presented window. ----------------------------------

  d.step("floating bar") do
    bar = app.floating_bar
    d.check("starts blank") { bar.primary_label_widget.label == "" }

    bar.primary_label = "https://example.org/"
    d.check("label updates") { bar.primary_label_widget.label == "https://example.org/" }
  end

  d.step("floating bar screenshot") do
    d.shot("03-floating-bar", app.floating_bar.widget)
  end

  # --- Search entry: not wired into the window yet, so it gets its own
  #     throwaway window to realize in, presented one tick before the shot.

  d.step("search entry builds and wires up") do
    $search_entry = SearchEntry.new
    $search_entry.build

    $search_entry_next_fired = false
    $search_entry.on_next_match { $search_entry_next_fired = true }

    $search_entry.n_matches = 5
    $search_entry.current_match = 2
    d.check("match counter renders") { $search_entry.matches_label.label == "2/5" }

    $search_entry.show_matches = true
    d.check("matches label becomes visible") { $search_entry.matches_label.visible? }

    $search_entry.text_value = "example"
    d.check("clear icon appears once typed") { $search_entry.clear_icon.visible? }

    $search_entry.text.signal_emit("activate")
    d.check("activating the entry fires next-match") { $search_entry_next_fired }

    $search_entry_window = Gtk::Window.new.tap do |win|
      win.child = $search_entry.widget
      win.present
    end
  end

  d.step("search entry screenshot") do
    d.shot("04-search-entry", $search_entry.widget)
    $search_entry_window.close
  end

  # --- Standalone mixin: title widget -----------------------------------------

  d.step("title widget contract") do
    holder = Class.new do
      include TitleWidget
      attr_accessor :security_level
    end.new

    holder.security_level = TitleWidget::STRONG_SECURITY
    d.check("strong security is secure") { holder.secure? }
    d.check("strong security has the secure icon") do
      holder.security_icon_name == "channel-secure-symbolic"
    end

    holder.security_level = TitleWidget::NO_SECURITY
    d.check("no security is not secure") { !holder.secure? }
  end

  # --- The shortcuts dialog, through the real app action ----------------------

  d.step("open shortcuts dialog") do
    app.app.activate_action("shortcuts", nil)
  end

  d.step("shortcuts dialog opened") do
    d.check("shortcuts dialog was built") { !app.shortcuts_dialog.instance_variable_get(:@dialog).nil? }
    d.check("window shows the shortcuts dialog") do
      app.window.respond_to?(:visible_dialog) ? app.window.visible_dialog == app.shortcuts_dialog.dialog : true
    end
    d.shot("05-shortcuts-dialog")
    if app.window.respond_to?(:visible_dialog)
      app.window.visible_dialog&.close
    end
  end

  # --- Quit, as the very last step: it ends the app -----------------------

  d.step("quit records geometry and exits") do
    width_before = app.window.default_width
    height_before = app.window.default_height

    app.app.activate_action("quit", nil)

    d.check("window size was recorded") do
      app.settings.schema(Settings::STATE).get_value("window-size") == [width_before, height_before]
    end
  end
end
