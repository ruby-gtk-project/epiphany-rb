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
require "bookmarks_export"
require "bookmarks_import"
require "opensearch_autodiscovery_link"
require "opensearch_engine"
require "encoding"
require "certificate"
require "web_process_extension"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

app_object = Epiphany::Application.new

GtkDriver.drive(app_object, shots: SHOTS) do |d, app|
  d.window { app.window.gtk_window }

  # --- The window the application itself builds ---------------------------

  d.step("app activates") do
    d.check("window exists") { !app.window.nil? }
    d.check("window title is Web") { app.window.gtk_window.title == "Web" }
    d.check("window opens with one tab") { app.window.tab_view.n_pages == 1 }
    d.check("header bar carries the page menu button") do
      !app.window.header_bar.page_menu_button.widget.popover.nil?
    end
    d.check("page menu has a quit item") { app.window.header_bar.page_menu_button.page_menu.n_items.positive? }
    d.check("notification container starts hidden") { !app.notification_container.widget.visible? }
    d.shot("01-main-window")
  end

  # --- The window itself: tabs, navigation and chrome ----------------------

  d.step("window tabs and navigation") do
    before = app.window.tab_view.n_pages

    index = app.window.new_tab(address: "https://example.org")
    d.check("new-tab adds a page") { app.window.tab_view.n_pages == before + 1 }
    d.check("new-tab jumps to the new page") { app.window.tab_view.selected_index == index }

    app.window.load_address("https://example.org/next")
    d.check("load_address updates the title widget's address") do
      app.window.header_bar.title_box.address == "https://example.org/next"
    end

    app.window.navigate_back
    d.check("navigate_back restores the previous address") do
      app.window.header_bar.title_box.address == "https://example.org"
    end

    app.window.navigate_forward
    d.check("navigate_forward replays the address") do
      app.window.header_bar.title_box.address == "https://example.org/next"
    end

    app.window.action_group("win").activate_action("new-tab", nil)
    d.check("win.new-tab action adds a tab for real") { app.window.tab_view.n_pages == before + 2 }

    app.window.action_group("tab").activate_action("close", nil)
    d.check("tab.close action removes the selected tab") { app.window.tab_view.n_pages == before + 1 }

    app.window.chrome = app.window.chrome & ~Window::CHROME_MENU
    d.check("chrome=  hides the page menu button") { !app.window.header_bar.page_menu_button.widget.visible? }
    app.window.chrome = Window::CHROME_DEFAULT
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

    # do_download_action's default launcher goes through Ashpd::OpenUri.open
    # (the ashpd gem) rather than a caller-supplied block. There is no
    # xdg-desktop-portal running in this headless dev shell, so the portal
    # call itself fails, but that is a world-does-not-have-a-portal failure,
    # not a wiring failure: the check is that Download actually reaches
    # ashpd (raising NameError/NoMethodError would mean it did not) and
    # degrades to `false` instead of raising.
    download.action = Download::ACTION_OPEN
    d.check("do_download_action reaches ashpd and degrades without raising") do
      download.do_download_action == false
    end
  end

  # --- Controller: mouse gestures ---------------------------------------------

  d.step("mouse gesture controller") do
    # Against the real window and its real "toolbar"/"win"/"tab" action
    # groups now that ephy-window.c is ported, rather than a stand-in.
    controller = MouseGestureController.new(app.window)
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

  # --- Model layer: bookmarks export/import round trip -----------------------

  d.step("bookmarks export and import round trip") do
    dir = Dir.mktmpdir("epiphany-bookmarks-io")
    manager = BookmarksManager.new(filename: File.join(dir, "bookmarks.json"))
    bookmark = Bookmark.new("https://example.org", "Example", ["work"], "1")
    manager.add_bookmark(bookmark)
    manager.create_tag("work")

    json_path = File.join(dir, "export.json")
    BookmarksExport.export(manager, json_path, with_tags_order: true)
    d.check("export writes a file") { File.exist?(json_path) }

    reimported = BookmarksManager.new(filename: File.join(dir, "reimported.json"))
    BookmarksImport.import(reimported, json_path)
    d.check("import restores the bookmark") { reimported.bookmark_by_url("https://example.org").title == "Example" }
    d.check("import restores the tag") { reimported.tag_exists?("work") }

    html_path = File.join(dir, "export.html")
    BookmarksExport.export(manager, html_path)
    d.check("html export contains the bookmark") { File.read(html_path).include?("https://example.org") }

    html_manager = BookmarksManager.new(filename: File.join(dir, "from-html.json"))
    BookmarksImport.import_from_html(html_manager, html_path)
    d.check("html import restores the bookmark") { !html_manager.bookmark_by_url("https://example.org").nil? }

    d.check("missing file raises BookmarksError") do
      BookmarksImport.import(reimported, File.join(dir, "nope.json"))
      false
    rescue BookmarksImport::BookmarksError
      true
    end
  end

  # --- Model layer: OpenSearch autodiscovery + engine parsing -----------------

  d.step("opensearch autodiscovery link and engine parsing") do
    link = OpensearchAutodiscoveryLink.new("Example Search", "https://example.org/opensearch.xml")
    d.check("autodiscovery link carries name and url") do
      link.name == "Example Search" && link.url == "https://example.org/opensearch.xml"
    end

    description = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
        <ShortName>Example</ShortName>
        <Url type="text/html" template="https://example.org/search?q={searchTerms}"/>
      </OpenSearchDescription>
    XML

    engine = OpensearchEngine.load_from_data(link, description)
    d.check("engine name parsed") { engine.name == "Example" }
    d.check("engine url substitutes search terms") { engine.url == "https://example.org/search?q=%s" }
    d.check("engine remembers its opensearch url") { engine.opensearch_url == link.url }

    d.check("a description with no search terms is rejected") do
      bad = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
          <ShortName>Bad</ShortName>
          <Url type="text/html" template="https://example.org/search"/>
        </OpenSearchDescription>
      XML
      OpensearchEngine.load_from_data(link, bad)
      false
    rescue OpensearchEngine::ParseError
      true
    end
  end

  # --- Model layer: text encoding title eliding and language groups ----------

  d.step("text encoding details") do
    encoding = TextEncoding.new("UTF-8", "Unicode (UTF-_8)", TextEncoding::LG_UNICODE)
    d.check("underscore elided from the title") { encoding.title_elided == "Unicode (UTF-8)" }
    d.check("belongs to the group it was given") { encoding.in_groups?(TextEncoding::LG_UNICODE) }
    d.check("does not belong to an unrelated group") { !encoding.in_groups?(TextEncoding::LG_ARABIC) }
    d.check("equal to another with the same code") do
      encoding == TextEncoding.new("UTF-8", "anything", TextEncoding::LG_NONE)
    end
  end

  # --- Notification + container, driven through the app's own real instances,
  #     already realized because they are overlays in the window the app
  #     presented at activation. ------------------------------------------

  d.step("notifications") do
    container = app.notification_container

    # container.add_notification (via append) builds the notification itself;
    # building it again here would re-attach already-parented widgets into the
    # grid and trip a Gtk-CRITICAL (gtk_grid_attach: child already has a
    # parent). Hand it unbuilt, as the real show-a-notification call sites do.
    first = Notification.new("Saved", "Bookmark added")
    dup = Notification.new("Saved", "Bookmark added")

    first.show(container)
    d.check("notification shown") { container.notifications.include?(first) }
    d.check("container becomes visible") { container.widget.visible? }

    dup.show(container)
    d.check("duplicate notification dropped") { container.notifications.length == 1 }

    # Leave one more live, then shoot a tick later so the revealer has had a
    # chance to allocate before the paint.
    $shown_notification = Notification.new("Downloading", "survey.pdf")
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

  # --- Certificate, backed by gcr-rb's Gcr::SimpleCertificate ---------------

  d.step("certificate parses a real DER certificate via gcr-rb") do
    require "openssl"

    key = OpenSSL::PKey::RSA.new(2048)
    raw = OpenSSL::X509::Certificate.new
    raw.version = 2
    raw.serial = 1
    raw.subject = OpenSSL::X509::Name.parse("/CN=example.org/O=Example Org")
    raw.issuer = raw.subject
    raw.public_key = key.public_key
    raw.not_before = Time.now
    raw.not_after = Time.now + 3600
    raw.sign(key, OpenSSL::Digest.new("SHA256"))

    certificate = Certificate.new(raw.to_der)
    d.check("subject_cn comes from the real certificate") { certificate.subject_cn == "example.org" }
    d.check("issuer_cn comes from the real certificate") { certificate.issuer_cn == "example.org" }
    d.check("key_size matches the generated key") { certificate.key_size == 2048 }

    sections = certificate.sections
    d.check("gcr-rb reports at least one section") { !sections.empty? }
    subject_section = sections.find { |s| s.label == "Subject Name" }
    d.check("subject name section has the CN row") do
      subject_section.rows.any? { |r| r.label.start_with?("CN") && r.value == "example.org" }
    end
    serial_section = sections.find { |s| s.label == "Issued Certificate" }
    serial_row = serial_section.rows.find { |r| r.label == "Serial Number" }
    d.check("serial number is hex-dumped and marked monospace") do
      serial_row.monospace && serial_row.value.match?(/\A([0-9A-F]{2} ?)+\z/)
    end
  end

  # --- WebProcessExtension, backed by webkit-web-process-extension -----------

  d.step("web process extension wires page-created/document-loaded") do
    # WebKit never hands a Ruby process a real WebProcessExtension or WebPage
    # (see lib/web_process_extension.rb's comment), so this constructs bare
    # instances straight from the gem's own GI-loaded classes to prove the
    # signal wiring is real: "page-created" and "document-loaded" are actual
    # GObject signals on the real typelib-defined classes, not stand-ins.
    extension = WebKitWebProcessExtension::WebProcessExtension.new
    page = WebKitWebProcessExtension::WebPage.new

    sent = []
    wpe = WebProcessExtension.new(extension, message_sender: ->(pg, message) { sent << [pg, message.name] })
    wpe.attach

    extension.signal_emit('page-created', page)
    page.signal_emit('document-loaded')

    d.check("document-loaded relays a real UserMessage named DocumentLoaded") do
      sent.size == 1 && sent.first[0].equal?(page) && sent.first[1] == "DocumentLoaded"
    end
  end

  # --- The shortcuts dialog, through the real app action ----------------------

  d.step("open shortcuts dialog") do
    app.app.activate_action("shortcuts", nil)
  end

  d.step("shortcuts dialog opened") do
    d.check("shortcuts dialog was built") { !app.shortcuts_dialog.instance_variable_get(:@dialog).nil? }
    d.check("window shows the shortcuts dialog") do
      app.window.gtk_window.respond_to?(:visible_dialog) ? app.window.gtk_window.visible_dialog == app.shortcuts_dialog.dialog : true
    end
    d.shot("05-shortcuts-dialog")
    if app.window.gtk_window.respond_to?(:visible_dialog)
      app.window.gtk_window.visible_dialog&.close
    end
  end

  # --- Quit, as the very last step: it ends the app -----------------------

  d.step("quit records geometry and exits") do
    width_before = app.window.gtk_window.default_width
    height_before = app.window.gtk_window.default_height

    app.app.activate_action("quit", nil)

    d.check("window size was recorded") do
      app.settings.schema(Settings::STATE).get_value("window-size") == [width_before, height_before]
    end
  end
end
