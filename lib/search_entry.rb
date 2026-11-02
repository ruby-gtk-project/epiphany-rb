# frozen_string_literal: true

require 'gtk4'

# SearchEntry is the find-in-page entry: a find icon that doubles as the result
# indicator, the text, a clear icon that appears once something is typed, and
# the "3/17" match counter.
#
# Ported from upstream's embed/ephy-search-entry.c. Upstream subclasses
# GtkWidget with a box layout and delegates GtkEditable to an inner GtkText,
# which the Ruby bindings cannot do — GtkEditable's delegate machinery is not
# exposed. The composition here is the same widget tree in the same order
# inside a GtkBox with the entry style class, the same icon names and css
# classes, the same "clear on release" gesture, and the same three actions
# (next match, previous match, stop search) on the same accelerators:
# Ctrl+G and Return for next, Ctrl+Shift+G and Shift+Return for previous,
# Escape to stop.
#
class SearchEntry
  # EphyFindResult from embed/ephy-embed-type-builtins, with the icon and
  # tooltip ephy_search_entry_set_find_result picks for each.
  FOUND         = :found
  NOTFOUND      = :notfound
  FOUNDWRAPPED  = :foundwrapped

  RESULT_ICONS = {
    FOUND        => ['edit-find-symbolic', nil],
    NOTFOUND     => ['face-uncertain-symbolic', 'Text not found'],
    FOUNDWRAPPED => ['view-wrapped-symbolic', 'Search wrapped back to the top'],
  }.freeze

  def initialize
    @show_matches = false
    @n_matches = 0
    @current_match = 0
    @find_result = FOUND
    @next_match_handlers = []
    @previous_match_handlers = []
    @stop_search_handlers = []
  end

  def build
    box.tap do |entry|
      entry.append(search_icon)
      entry.append(text)
      entry.append(clear_icon)
      entry.append(matches_label)

      text.tap do |field|
        field.signal_connect_after('changed') { update_clear_icon }
        field.signal_connect('activate') { emit_next_match }
      end

      clear_icon.add_controller(clear_gesture)

      clear_gesture.tap do |gesture|
        gesture.signal_connect('pressed') { gesture.set_state(:claimed) }
        gesture.signal_connect('released') { self.text_value = '' }
      end

      box.add_controller(shortcuts)

      update_matches
    end
  end

  def widget = box

  def grab_focus = text.grab_focus

  # The three actions upstream declares as signals, which FindToolbar binds to.
  def on_next_match(&callback)
    @next_match_handlers << callback
    callback
  end

  def on_previous_match(&callback)
    @previous_match_handlers << callback
    callback
  end

  def on_stop_search(&callback)
    @stop_search_handlers << callback
    callback
  end

  def text_value = text.text

  def text_value=(value)
    text.text = value.to_s
  end

  def placeholder_text = text.placeholder_text

  def placeholder_text=(value)
    unless value == placeholder_text
      text.placeholder_text = value
    end
  end

  attr_reader :show_matches, :n_matches, :current_match, :find_result

  def show_matches=(show)
    (!!show).then do |wanted|
      unless wanted == @show_matches
        @show_matches = wanted
        matches_label.visible = wanted
      end
    end
  end

  def n_matches=(count)
    unless count.to_i == @n_matches
      @n_matches = count.to_i
      update_matches
    end
  end

  def current_match=(index)
    unless index.to_i == @current_match
      @current_match = index.to_i
      update_matches
    end
  end

  # ephy_search_entry_set_find_result: the find icon carries the outcome, with
  # a tooltip for the two failure cases.
  def find_result=(result)
    unless result == @find_result
      @find_result = result
      RESULT_ICONS.fetch(result).then do |(icon_name, tooltip)|
        search_icon.icon_name = icon_name
        search_icon.tooltip_text = tooltip
      end
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |entry|
      entry.add_css_class('entry')
      entry.hexpand = false
    end
  end

  def search_icon
    @search_icon ||= Gtk::Image.new(icon_name: 'edit-find-symbolic').tap do |image|
      image.accessible_role = :presentation
    end
  end

  def text
    @text ||= Gtk::Text.new.tap do |field|
      field.hexpand = true
    end
  end

  def clear_icon
    @clear_icon ||= Gtk::Image.new(icon_name: 'edit-clear-symbolic').tap do |image|
      image.accessible_role = :presentation
      image.visible = false
    end
  end

  def matches_label
    @matches_label ||= Gtk::Label.new.tap do |label|
      label.add_css_class('dim-label')
      label.add_css_class('numeric')
      label.visible = false
    end
  end

  def clear_gesture = @clear_gesture ||= Gtk::GestureClick.new

  def shortcuts
    @shortcuts ||= Gtk::ShortcutController.new.tap do |controller|
      controller.scope = :local
      SHORTCUTS.each do |(accelerator, action)|
        controller.add_shortcut(shortcut_for(accelerator, action))
      end
    end
  end

  # The accelerators upstream installs with gtk_widget_class_add_binding_signal.
  SHORTCUTS = [
    ['<Control>g', :next],
    ['Return', :next],
    ['<Control><Shift>g', :previous],
    ['<Shift>Return', :previous],
    ['<Shift>ISO_Enter', :previous],
    ['<Shift>KP_Enter', :previous],
    ['Escape', :stop],
  ].freeze

  private

    # Gtk::ShortcutTrigger has no parse_string in the Ruby bindings, so the
    # accelerator goes through Gtk.accelerator_parse — which returns
    # [ok, keyval, modifiers] — and into a KeyvalTrigger.
    def shortcut_for(accelerator, action)
      Gtk.accelerator_parse(accelerator).then do |(ok, keyval, modifiers)|
        unless ok
          raise ArgumentError, "could not parse accelerator #{accelerator}"
        end

        Gtk::Shortcut.new(
          Gtk::KeyvalTrigger.new(keyval, modifiers),
          Gtk::CallbackAction.new { |_widget, _args| dispatch(action) },
        )
      end
    end

    def dispatch(action)
      case action
      when :next then emit_next_match
      when :previous then emit_previous_match
      when :stop then emit_stop_search
      end
      true
    end

    def update_clear_icon
      clear_icon.visible = !text.text.to_s.empty?
    end

    def update_matches
      matches_label.label = "#{@current_match}/#{@n_matches}"
    end

    def emit_next_match
      @next_match_handlers.each { |callback| callback.call(self) }
    end

    def emit_previous_match
      @previous_match_handlers.each { |callback| callback.call(self) }
    end

    def emit_stop_search
      @stop_search_handlers.each { |callback| callback.call(self) }
    end
end
