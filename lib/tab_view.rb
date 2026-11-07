# frozen_string_literal: true

require 'adwaita'

require_relative 'settings'

# Ported from src/ephy-tab-view.c
#
# Wraps a single Adwaita::TabView, the window's one strip of pages. Each
# page's content is whatever widget the window gives it — upstream always
# hands it an EphyEmbed (a WebKit view); this round of the port has no
# embed/web-view layer yet, so TabView is written generically over any
# Gtk::Widget and the window supplies placeholder content per tab. Every
# operation below (add, close, pin, reorder-by-selection, iterate) is the
# real AdwTabView call upstream makes, not a stand-in.
class TabView
  def initialize(settings: Settings.default)
    @settings = settings
    @current_page = nil
  end

  def widget = tab_view

  def tab_view
    @tab_view ||= Adwaita::TabView.new.tap do |view|
      # https://gitlab.gnome.org/GNOME/epiphany/-/issues/2296
      view.remove_shortcuts(
        Adwaita::TabViewShortcuts::CONTROL_HOME |
        Adwaita::TabViewShortcuts::CONTROL_END |
        Adwaita::TabViewShortcuts::CONTROL_SHIFT_HOME |
        Adwaita::TabViewShortcuts::CONTROL_SHIFT_END
      )

      view.signal_connect('notify::selected-page') do
        @current_page = view.selected_page
      end
    end
  end

  # Attaches a tab bar above the strip and wires its visibility to the
  # org.gnome.Epiphany.ui settings upstream reads in
  # visibility_policy_changed_cb / expand_changed_cb.
  def attach_tab_bar(tab_bar)
    tab_bar.view = tab_view
    sync_tab_bar_visibility(tab_bar)

    ui_schema.connect('tabs-bar-visibility-policy') { sync_tab_bar_visibility(tab_bar) }
    ui_schema.connect('expand-tabs-bar') { tab_bar.expand_tabs = ui_schema.get_boolean('expand-tabs-bar') }

    tab_bar
  end

  # ephy_tab_view_add_tab: appends (or inserts at +position+, or inserts
  # as a sibling of +parent+) and optionally jumps to the new page.
  def add_tab(child, parent: nil, position: nil, jump_to: true)
    page =
      if parent
        tab_view.add_page(child, page_for(parent))
      elsif position.nil? || position < 0
        tab_view.append(child)
      else
        tab_view.insert(child, position)
      end

    tab_view.selected_page = page if jump_to

    tab_view.get_page_position(page)
  end

  def next = tab_view.select_next_page

  def pin = (current_page && tab_view.set_page_pinned(current_page, true))

  def unpin = (current_page && tab_view.set_page_pinned(current_page, false))

  def close(widget) = tab_view.close_page(page_for(widget))

  def close_selected = (current_page && tab_view.close_page(current_page))

  def close_left = (current_page && tab_view.close_pages_before(current_page))

  def close_right = (current_page && tab_view.close_pages_after(current_page))

  def close_other = (current_page && tab_view.close_other_pages(current_page))

  def close_all
    close_other
    close_selected
  end

  def each_page
    n_pages.times { |i| yield tab_view.get_nth_page(i).child }
  end

  def n_pages = tab_view.n_pages

  def selected_index
    page = tab_view.selected_page
    page ? tab_view.get_page_position(page) : -1
  end

  def page_index(widget) = tab_view.get_page_position(page_for(widget))

  def nth_page(index) = tab_view.get_nth_page(index).child

  def select_nth_page(index) = (tab_view.selected_page = tab_view.get_nth_page(index))

  def select_page(widget)
    page_for(widget).tap { |page| tab_view.selected_page = page if page }.then { |page| !!page }
  end

  def selected_page
    page = tab_view.selected_page
    page&.child
  end

  def pages
    (0...n_pages).map { |i| tab_view.get_nth_page(i).child }
  end

  def pinned?(widget) = page_for(widget).pinned?

  private

  # Upstream caches the page the context menu was last opened on
  # ("setup-menu") and falls back to the selected page; this port has no
  # context menu wired yet, so this is simply the selected page.
  def current_page = @current_page || tab_view.selected_page

  def page_for(widget) = tab_view.get_page(widget)

  def sync_tab_bar_visibility(tab_bar)
    policy = ui_schema.get_string('tabs-bar-visibility-policy')
    tab_bar.autohide = policy != 'always'
    tab_bar.visible = policy != 'never'
  end

  def ui_schema = @ui_schema ||= @settings.schema(Settings::UI)
end
