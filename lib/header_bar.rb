# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'action_bar_start'
require_relative 'action_bar_end'
require_relative 'page_menu_button'
require_relative 'title_box'

# HeaderBar is the window's top bar: the navigation cluster on the start
# side, the title/address widget in the middle (clamped to a maximum width,
# as upstream does outside Pantheon), the page menu and the bookmarks /
# downloads cluster on the end side, plus a restore button that appears only
# while fullscreen.
#
# Ported from src/ephy-header-bar.c. Upstream picks a LocationEntry or a
# TitleBox for the centre widget depending on EphyEmbedShellMode; this round
# has no editable LocationEntry yet (not ported), so the header bar always
# shows the read-only TitleBox. Chrome-based visibility
# (sync_chromes_visibility) and the fullscreen restore-button swap
# (fullscreen_changed_cb) are both wired against the window object passed
# in, exactly as upstream connects "notify::chrome" / "notify::fullscreened".
class HeaderBar
  def initialize(window:, toggle_bookmarks: nil)
    @window = window
    @action_bar_start = ActionBarStart.new
    @action_bar_end = ActionBarEnd.new(toggle_bookmarks: toggle_bookmarks)
    @page_menu_button = PageMenuButton.new
    connect_window
  end

  attr_reader :action_bar_start, :action_bar_end, :page_menu_button

  def widget = root

  def root
    @root ||= Gtk::Box.new(:vertical, 0).tap { |box| box.append(header_bar) }
  end

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.pack_start(@action_bar_start.widget)
      bar.title_widget = title_container
      bar.pack_end(restore_button)
      bar.pack_end(@page_menu_button.widget)
      bar.pack_end(@action_bar_end.widget)
    end
  end

  # The event-box + clamp wrapper ephy_header_bar_constructed builds around
  # the title widget outside Pantheon, keeping it from stretching past
  # 860px on a wide window.
  def title_container
    @title_container ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.hexpand = true
      clamp.maximum_size = 860
      clamp.tightening_threshold = 560
      clamp.child = title_box.widget
    end
  end

  def title_box = @title_box ||= TitleBox.new

  def restore_button
    @restore_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'view-restore-symbolic'
      button.tooltip_text = 'Exit Fullscreen'
      button.visible = false
      button.action_name = 'win.fullscreen'
    end
  end

  private

  def connect_window
    @window.signal_connect('notify::fullscreened') { sync_fullscreen }
  end

  # fullscreen_changed_cb: hides the window's own title buttons and shows
  # the restore button instead, while fullscreen.
  def sync_fullscreen
    fullscreen = @window.fullscreened?
    header_bar.show_start_title_buttons = !fullscreen
    header_bar.show_end_title_buttons = !fullscreen
    restore_button.visible = fullscreen
  end
end
