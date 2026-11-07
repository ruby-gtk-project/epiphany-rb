# frozen_string_literal: true

require 'gtk4'

require_relative 'settings'

# MouseGestureController recognizes middle-button drag gestures over the web
# view and activates the window action each gesture maps to: back/forward/new
# tab for a single stroke, close/reload for a two-stroke sequence.
#
# Ported from upstream's src/ephy-mouse-gesture-controller.c. Upstream attaches
# a GtkGestureDrag to the window in the capture phase, restricts it to the
# middle button, and only lets the gesture claim the sequence when it began
# over the web view widget (so left/middle-click selection inside a page is
# left alone). The direction of each leg of the drag is guessed the same way
# upstream does: whichever axis moved at least twice as far as the other.
#
# `window` is anything that responds to `widget` (the Gtk::Widget the
# controller attaches to and picks against) and `action_group(name)` (handing
# back the "toolbar"/"win"/"tab" Gio::ActionGroup upstream's ephy-window.c
# exposes under those names) — ephy-window.c itself is not ported yet, so this
# class depends only on that narrow interface rather than on EphyWindow.
class MouseGestureController
  RIGHT = :right
  LEFT  = :left
  DOWN  = :down
  UP    = :up

  NUM_SEQUENCES = 2

  # sequence_pos => [[leg_1, leg_2, ...], action_group_name, action_name]
  # ephy_mouse_gesture_controller drag_end_cb's two switches, flattened to a
  # table so the lookup here matches it exactly.
  GESTURES = [
    [[LEFT],        'toolbar', 'navigation-back'],
    [[RIGHT],       'toolbar', 'navigation-forward'],
    [[DOWN],        'win',     'new-tab'],
    [[DOWN, RIGHT], 'tab',     'close'],
    [[UP, DOWN],    'toolbar', 'reload'],
  ].freeze

  def initialize(window, web_view: nil)
    @window = window
    @web_view = web_view
    reset
  end

  def web_view=(web_view)
    @web_view = web_view
  end

  def unset_web_view = @web_view = nil

  # ephy_mouse_gesture_controller_constructed
  def attach
    gesture.tap do |g|
      g.propagation_phase = :capture
      g.button = Gdk::BUTTON_MIDDLE
      g.exclusive = true if g.respond_to?(:exclusive=)

      g.signal_connect('drag-begin') { |_, x, y| on_drag_begin(x, y) }
      g.signal_connect('drag-update') { |_, x, y| on_drag_update(x, y) }
      g.signal_connect('drag-end') { |_, x, y| on_drag_end(x, y) }
      g.signal_connect('cancel') { reset }
    end
    @window.widget.add_controller(gesture)
    self
  end

  def detach
    @window.widget.remove_controller(gesture)
    self
  end

  def gesture = @gesture ||= Gtk::GestureDrag.new

  private

    def reset
      @direction = nil
      @sequence = []
      @last_x = 0
      @last_y = 0
      @active = false
    end

    # drag_begin_cb: deny the sequence up front, rather than claim it and
    # back out later, exactly as upstream does with GTK_EVENT_SEQUENCE_DENIED.
    def on_drag_begin(start_x, start_y)
      unless Settings.web.get_boolean('enable-mouse-gestures')
        gesture.set_state(:denied)
        return
      end

      picked = @window.widget.pick(start_x, start_y, :default)
      gesture.set_state(:denied) if !@web_view || picked != @web_view
    end

    def on_drag_update(offset_x, offset_y)
      delta_x = offset_x - @last_x
      delta_y = offset_y - @last_y
      @last_x = offset_x
      @last_y = offset_y

      @active = true if !@active && Gtk.drag_check_threshold(@window.widget, 0, 0, offset_x, offset_y)

      return unless @active && @sequence.size < NUM_SEQUENCES

      direction = guess_direction(delta_x, delta_y)
      return unless direction
      return if direction == @direction

      @sequence << direction
      @direction = direction
    end

    def on_drag_end(_offset_x, _offset_y)
      return unless @active

      gesture.set_state(:claimed)
      activate_gesture
      reset
    end

    # "Try to guess direction": the axis that moved at least twice as far as
    # the other wins; a near-diagonal drag updates neither leg.
    def guess_direction(delta_x, delta_y)
      if delta_x.abs > delta_y.abs * 2
        delta_x > 0 ? RIGHT : LEFT
      elsif delta_y.abs > delta_x.abs * 2
        delta_y > 0 ? DOWN : UP
      end
    end

    def activate_gesture
      GESTURES.find { |legs, _, _| legs == @sequence }.then do |match|
        next unless match

        _, group_name, action_name = match
        @window.action_group(group_name)&.activate_action(action_name, nil)
      end
    end
end
