# frozen_string_literal: true

require 'gtk4'

require_relative 'downloads_manager'

# ActionBarEnd is the header bar's trailing cluster: the bookmarks toggle,
# the tab overview button and the downloads indicator that reveals itself
# once a download starts and briefly accents while one needs attention.
#
# Ported from src/ephy-action-bar-end.c. Upstream also hosts the
# browser-action popover for installed web extensions
# (ephy-web-extension-manager.c); that manager is not ported this round, so
# this port leaves that button out rather than wire it to nothing.
class ActionBarEnd
  def initialize(downloads_manager: DownloadsManager.new, toggle_bookmarks: nil)
    @downloads_manager = downloads_manager
    @toggle_bookmarks = toggle_bookmarks || -> {}
    connect_downloads_manager
  end

  def widget = root

  def root
    @root ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.append(downloads_revealer)
      box.append(bookmarks_button)
      box.append(overview_button)
    end
  end

  def bookmarks_button
    @bookmarks_button ||= Gtk::ToggleButton.new.tap do |button|
      button.icon_name = 'user-bookmarks-symbolic'
      button.tooltip_text = 'Bookmarks'
      button.signal_connect('clicked') { @toggle_bookmarks.call }
    end
  end

  def overview_button
    @overview_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'view-grid-symbolic'
      button.tooltip_text = 'Tab Overview'
      button.action_name = 'win.show-tab-overview'
    end
  end

  # ephy_action_bar_end_get_downloads_revealer: the slot header_bar.rb
  # size-groups against ActionBarStart's placeholder.
  def downloads_revealer
    @downloads_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = @downloads_manager.downloads.any?
      revealer.child = downloads_button
    end
  end

  def downloads_button
    @downloads_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'ephy-download-symbolic'
      button.tooltip_text = 'Downloads'
    end
  end

  # ephy_action_bar_end_set_show_bookmarks_button
  def show_bookmarks_button=(show)
    bookmarks_button.visible = show
  end

  # ephy_action_bar_end_show_downloads
  def show_downloads
    downloads_button.popup if downloads_button.visible
  end

  private

  def connect_downloads_manager
    @downloads_manager.on_download_added do
      downloads_revealer.reveal_child = true
      add_attention
    end

    @downloads_manager.on_download_removed do
      downloads_revealer.reveal_child = @downloads_manager.downloads.any?
    end

    @downloads_manager.on_show_downloads { show_downloads }
  end

  # add_attention_timeout_cb's css-class flash, run synchronously rather
  # than on a timeout — the port has no GLib main loop idle this would ride
  # on outside a running Gtk::Application.
  def add_attention
    downloads_button.add_css_class('accent')
    GLib::Timeout.add(2000) do
      downloads_button.remove_css_class('accent')
      false
    end
  end
end
