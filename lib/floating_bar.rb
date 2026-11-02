# frozen_string_literal: true

require 'gtk4'

# FloatingBar is the small card that floats over the page to show the URL a
# link under the pointer would go to.
#
# Ported from upstream's embed/ephy-floating-bar.c: a GtkBox carrying one
# middle-ellipsized single-line label, with the floating-bar and card style
# classes and `can-target` off so the pointer passes straight through to the
# page underneath. The .floating-bar class is the one src/resources/style.css
# defines, which Styles installs.
#
class FloatingBar
  def initialize(primary_label: nil)
    @primary_label = nil
    build
    self.primary_label = primary_label
  end

  def build
    box.tap do |bar|
      bar.append(primary_label_widget)
    end
  end

  def widget = box

  attr_reader :primary_label

  def primary_label=(label)
    unless label == @primary_label
      @primary_label = label
      primary_label_widget.label = label.to_s
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |bar|
      bar.can_target = false
      bar.add_css_class('floating-bar')
      bar.add_css_class('card')
    end
  end

  def primary_label_widget
    @primary_label_widget ||= Gtk::Label.new.tap do |label|
      label.ellipsize = :middle
      label.single_line_mode = true
    end
  end
end
