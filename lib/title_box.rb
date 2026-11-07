# frozen_string_literal: true

require 'gtk4'
require 'glib2'

require_relative 'title_widget'

# Ported from src/ephy-title-box.c
#
# The read-only header-bar title shown when the window has no editable
# location entry (web-app mode): the app name on top, the page's address
# and a security icon underneath. Implements the TitleWidget contract
# (address / security_level) LocationEntry will also satisfy, so HeaderBar
# can swap between the two without caring which one it has.
class TitleBox
  include TitleWidget

  def widget = root

  def root
    @root ||= Gtk::Box.new(:vertical, 0).tap do |vbox|
      vbox.valign = :center
      vbox.append(title_label)
      vbox.append(subtitle_box)
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new(GLib.application_name || 'epiphany').tap do |label|
      label.add_css_class('title')
      label.single_line_mode = true
      label.ellipsize = :end
    end
  end

  def subtitle_box
    @subtitle_box ||= Gtk::Box.new(:horizontal, 4).tap do |hbox|
      hbox.add_css_class('subtitle')
      hbox.halign = :center
      hbox.valign = :baseline_fill
      hbox.append(security_button)
      hbox.append(subtitle_label)
    end
  end

  def security_button
    @security_button ||= Gtk::MenuButton.new.tap do |button|
      button.valign = :baseline_fill
      button.add_css_class('entry-icon')
      button.visible = false
    end
  end

  def subtitle_label
    @subtitle_label ||= Gtk::Label.new.tap do |label|
      label.valign = :baseline_fill
      label.single_line_mode = true
      label.ellipsize = :end
      label.selectable = true
    end
  end

  # ephy_title_box_title_widget_get/set_address
  def address = subtitle_label.text

  def address=(value)
    subtitle_label.text = value if value && !value.empty?
  end

  # ephy_title_box_title_widget_get/set_security_level
  def security_level = @security_level ||= TitleWidget::TO_BE_DETERMINED

  def security_level=(value)
    icon_name = TitleWidget.icon_name(value)
    security_button.icon_name = icon_name if icon_name
    security_button.visible = !!icon_name
    @security_level = value
  end

  # ephy_title_box_reset
  def reset(title, address)
    title_label.text = title
    self.address = address
  end
end
