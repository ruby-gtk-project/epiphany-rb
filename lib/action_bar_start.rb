# frozen_string_literal: true

require 'gtk4'

# ActionBarStart is the header bar's leading cluster: back/forward
# navigation and the combined stop/reload button, plus the placeholder slot
# header_bar.rb size-groups against the downloads revealer so the title
# does not jump sideways as that button appears and disappears.
#
# Ported from src/ephy-action-bar-start.c. Upstream's back/forward buttons
# pop a history menu built from WebKit's back-forward list and read/write an
# EphyEmbed; this round of the port has no WebKit view layer (ephy-embed.c
# is not ported), so the buttons are plain "win.navigation-back" /
# "win.navigation-forward" actionables with no history popover, and the
# window supplies what those actions do.
class ActionBarStart
  def widget = root

  # EphyActionBarStart is itself a GtkBox upstream; this is that box, holding
  # the navigation cluster, the reload button and the size-group placeholder
  # in the same order the .ui template lays them out.
  def root
    @root ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.append(navigation_box)
      box.append(combined_stop_reload_button)
      box.append(placeholder)
    end
  end

  # ephy_action_bar_start_get_navigation_box: what header_bar.rb toggles
  # visible/invisible as the window's chrome changes.
  def navigation_box
    @navigation_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class('linked')
      box.append(back_button)
      box.append(forward_button)
    end
  end

  def back_button
    @back_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-previous-symbolic'
      button.tooltip_text = 'Back'
      button.action_name = 'toolbar.navigation-back'
    end
  end

  def forward_button
    @forward_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'go-next-symbolic'
      button.tooltip_text = 'Forward'
      button.action_name = 'toolbar.navigation-forward'
    end
  end

  def combined_stop_reload_button
    @combined_stop_reload_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'view-refresh-symbolic'
      button.tooltip_text = 'Reload'
      button.action_name = 'toolbar.reload'
    end
  end

  # ephy_action_bar_start_get_placeholder: an invisible widget the end
  # cluster's downloads revealer is size-grouped against, so the title
  # doesn't shift when that button appears.
  def placeholder
    @placeholder ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.visible = false }
  end
end
