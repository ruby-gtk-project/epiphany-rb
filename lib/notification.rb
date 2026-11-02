# frozen_string_literal: true

require 'adwaita'

# Notification is the in-app notification banner: a headline, a body and a
# close button, inside the app-notification style.
#
# Ported from upstream's lib/ephy-notification.c, which is an AdwBin holding a
# GtkGrid with the two wrapped, left-aligned labels in column 0 and the flat
# close button spanning both rows in column 1. The close button emits ::close,
# which NotificationContainer listens for to take the banner out again.
#
# Upstream's head/body are construct-only properties, so they are constructor
# arguments here.
#
class Notification
  attr_reader :head, :body

  def initialize(head, body)
    @head = head.to_s
    @body = body.to_s
    @close_handlers = []
  end

  def build
    bin.tap do |widget|
      widget.child = grid

      grid.tap do |layout|
        layout.attach(
          head_label,
          0,
          0,
          1,
          1,
        )
        layout.attach(
          body_label,
          0,
          1,
          1,
          1,
        )
        layout.attach(
          close_button,
          1,
          0,
          1,
          2,
        )

        close_button.signal_connect('clicked') { emit_close }
      end
    end
  end

  # The ::close signal upstream declares, which the container connects to.
  def on_close(&callback)
    @close_handlers << callback
    callback
  end

  # ephy_notification_is_duplicate: the container drops a second banner with
  # the same head and body rather than stacking it.
  def duplicate?(other) = other.head == @head && other.body == @body

  # ephy_notification_show
  def show(container = NotificationContainer.default)
    container.add_notification(self)
  end

  def widget = bin

  def bin
    @bin ||= Adwaita::Bin.new.tap do |widget|
      widget.add_css_class('app-notification')
    end
  end

  def grid = @grid ||= Gtk::Grid.new

  def head_label
    @head_label ||= Gtk::Label.new(@head).tap do |label|
      label.wrap = true
      label.xalign = 0
      label.hexpand = true
    end
  end

  def body_label
    @body_label ||= Gtk::Label.new(@body).tap do |label|
      label.wrap = true
      label.xalign = 0
      label.hexpand = true
    end
  end

  def close_button
    @close_button ||= Gtk::Button.new(icon_name: 'window-close-symbolic').tap do |button|
      button.focus_on_click = false
      button.margin_top = 6
      button.margin_bottom = 6
      button.margin_start = 6
      button.margin_end = 6
      button.add_css_class('flat')
    end
  end

  private

    def emit_close
      @close_handlers.each { |callback| callback.call(self) }
    end
end

require_relative 'notification_container'
