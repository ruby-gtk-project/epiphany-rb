# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "../settings"
require_relative "../encodings"
require_relative "../bookmarks_manager"
require_relative "../search_engine_manager"
require_relative "../permissions_manager"
require_relative "../sync_utils"
require_relative "../styles"
require_relative "../shortcuts_dialog"
require_relative "../notification"
require_relative "../notification_container"
require_relative "../floating_bar"
require_relative "../search_entry"
require_relative "../suggestion"
require_relative "../link"
require_relative "../title_widget"

module Epiphany
  # The port's application and shell: it owns the single process-wide copy of
  # each model the rest of the port reads — settings, bookmarks, search
  # engines, permissions, encodings — and the one window built so far.
  #
  # Stands in for upstream's src/ephy-shell.c and src/ephy-main.c as far as the
  # ported components reach. The window itself (src/ephy-window.c) and the
  # browsing stack are not ported yet, so the window's content is a status page
  # listing what this round landed; the app actions below are the ones whose
  # targets exist, bound to the accelerators src/resources/gtk/shortcuts-dialog.blp
  # advertises for them.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "org.rubygtkproject.Epiphany"

    # The app-level actions from upstream's ACTION_ENTRIES whose handlers the
    # ported components can satisfy, with the accelerators the shortcuts
    # dialog lists for them.
    ACCELERATORS = {
      "shortcuts" => ["<Primary>question"],
      "quit"      => ["<Primary>Q"],
    }.freeze

    def build
      app.tap do
        app.signal_connect("startup") do
          Styles.load
        end

        app.signal_connect("activate") do
          ACCELERATORS.each do |name, accelerators|
            app.set_accels_for_action("app.#{name}", accelerators)
          end

          app.add_action(shortcuts_action)
          app.add_action(quit_action)

          window.tap do |win|
            win.content = toast_overlay
            settings.apply_to(win)
          end

          toast_overlay.tap do |overlay|
            overlay.child = overlay_layout

            overlay_layout.tap do |layout|
              layout.child = toolbar_view
              layout.add_overlay(notification_container.widget)
              layout.add_overlay(floating_bar.widget)
            end
          end

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = status_page

            header_bar.pack_end(menu_button)
          end

          window.present
        end
      end
    end

    def run(argv = ARGV) = app.run(argv)

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    # The process-wide models, the ones ephy_shell_get_* hands out upstream.
    def settings = @settings ||= Settings.default

    def bookmarks_manager = @bookmarks_manager ||= BookmarksManager.new

    def search_engine_manager = @search_engine_manager ||= SearchEngineManager.new

    def permissions_manager = @permissions_manager ||= PermissionsManager.new

    def encodings = @encodings ||= TextEncodings.new

    def window
      @window ||= Adwaita::ApplicationWindow.new(app).tap do |win|
        win.title = "epiphany"
        win.set_default_size(800, 600)
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    # The overlay the floating bar and the notification stack sit in, which
    # upstream's window keeps over the page.
    def overlay_layout = @overlay_layout ||= Gtk::Overlay.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = "Main Menu"
        button.menu_model = page_menu
      end
    end

    # The slice of src/resources/gtk/page-menu-button.blp's menu whose actions
    # exist: the rest of that menu arrives with the page menu itself.
    def page_menu
      @page_menu ||= Gio::Menu.new.tap do |menu|
        menu.append("Keyboard Shortcuts", "app.shortcuts")
        menu.append("Quit", "app.quit")
      end
    end

    def shortcuts_action
      @shortcuts_action ||= Gio::SimpleAction.new("shortcuts").tap do |action|
        action.signal_connect("activate") { shortcuts_dialog.present(window) }
      end
    end

    def quit_action
      @quit_action ||= Gio::SimpleAction.new("quit").tap do |action|
        action.signal_connect("activate") do
          settings.record_geometry(window)
          app.quit
        end
      end
    end

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new

    def notification_container = @notification_container ||= NotificationContainer.default

    def floating_bar = @floating_bar ||= FloatingBar.new

    # What this round of the port landed, so the window says something true
    # rather than advertising a browser that is not here yet.
    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = "epiphany"
        page.description = "Ported so far: settings, bookmarks, search engines, " \
                           "permissions, encodings, notifications and the shortcuts dialog. " \
                           "The browsing window is not written yet."
        page.icon_name = "applications-engineering-symbolic"
      end
    end
  end
end
