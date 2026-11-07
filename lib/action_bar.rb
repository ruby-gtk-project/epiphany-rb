# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'downloads_manager'
require_relative 'page_menu_button'

# ActionBar is the bottom toolbar ToolbarView shows on narrow windows
# instead of (in addition to) the header bar's action clusters: back,
# forward, a tab-count button that opens the tab overview, bookmarks and the
# page menu.
#
# Ported from src/ephy-action-bar.c. Upstream reads the window's EphyTabView
# to bind AdwTabButton to the real AdwTabView and shows a downloads button
# fed from the same EphyDownloadsManager the header bar's end cluster reads;
# this port does the same against the TabView and DownloadsManager it is
# given, with the WebKit-backed history popover left out for the reason
# ActionBarStart's comment gives.
class ActionBar
  def initialize(tab_view:, downloads_manager: DownloadsManager.new)
    @tab_view = tab_view
    @downloads_manager = downloads_manager
    @page_menu_button = PageMenuButton.new
    connect_downloads_manager
  end

  def widget = toolbar

  def toolbar
    @toolbar ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.add_css_class('toolbar')
      box.append(back_button)
      box.append(forward_button)
      box.append(tab_button)
      box.append(bookmarks_button)
      box.append(downloads_button)
      box.append(spacer)
      box.append(@page_menu_button.widget)
    end
  end

  def back_button
    @back_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-previous-symbolic'
      button.action_name = 'toolbar.navigation-back'
    end
  end

  def forward_button
    @forward_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-next-symbolic'
      button.action_name = 'toolbar.navigation-forward'
    end
  end

  def tab_button
    @tab_button ||= Adwaita::TabButton.new.tap { |button| button.view = @tab_view.tab_view }
  end

  def bookmarks_button
    @bookmarks_button ||= Gtk::ToggleButton.new.tap do |button|
      button.icon_name = 'user-bookmarks-symbolic'
      button.tooltip_text = 'Bookmarks'
    end
  end

  def downloads_button
    @downloads_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'ephy-download-symbolic'
      button.tooltip_text = 'Downloads'
      button.visible = @downloads_manager.downloads.any?
    end
  end

  def spacer = @spacer ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.hexpand = true }

  private

  def connect_downloads_manager
    @downloads_manager.on_download_added { downloads_button.visible = true }
    @downloads_manager.on_download_removed { downloads_button.visible = @downloads_manager.downloads.any? }
  end
end
