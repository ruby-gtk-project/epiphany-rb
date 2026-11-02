# frozen_string_literal: true

require 'adwaita'

# NotificationContainer is the stack the in-app notifications appear in,
# centred against the top of the window.
#
# Ported from upstream's lib/ephy-notification-container.c: an AdwBin holding a
# GtkRevealer around a vertical 6px box, aligned centre/start, hidden while
# empty. It is a process-wide singleton upstream — a notification can be raised
# from anywhere and has to find the container without being handed one — so
# `default` plays the part of ephy_notification_container_get_default.
#
# Adding a notification that duplicates one already shown is dropped rather
# than stacked, and the last notification closing hides the container again.
#
class NotificationContainer
  class << self
    def default = @default ||= new.tap(&:build)

    def reset_default!
      @default = nil
    end
  end

  def initialize
    @notifications = []
  end

  def build
    bin.tap do |widget|
      widget.child = revealer

      revealer.tap do |reveal|
        reveal.child = box
      end
    end
  end

  def widget = bin

  attr_reader :notifications

  # ephy_notification_container_add_notification
  def add_notification(notification)
    if @notifications.any? { |shown| shown.duplicate?(notification) }
      nil
    else
      append(notification)
    end
  end

  def bin
    @bin ||= Adwaita::Bin.new.tap do |widget|
      widget.halign = :center
      widget.valign = :start
      widget.visible = false
    end
  end

  def revealer = @revealer ||= Gtk::Revealer.new

  def box = @box ||= Gtk::Box.new(:vertical, 6)

  private

    def append(notification)
      notification.tap do |item|
        @notifications << item
        box.append(item.build)
        bin.visible = true
        revealer.reveal_child = true
        item.on_close { remove_notification(item) }
      end
    end

    def remove_notification(notification)
      box.remove(notification.widget)
      @notifications.delete(notification)

      if @notifications.empty?
        bin.visible = false
        revealer.reveal_child = false
      end
    end
end
