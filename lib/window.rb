# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'action_helper'
require_relative 'action_bar'
require_relative 'header_bar'
require_relative 'tab_view'
require_relative 'title_widget'
require_relative 'downloads_manager'

# Window is the browser's main window: the tab strip, the header bar above
# it, the bottom action bar narrow layouts use instead, and the "win" /
# "toolbar" / "tab" action groups the rest of the UI (menus, the mouse
# gesture controller, the keyboard shortcuts) activates.
#
# Ported from src/ephy-window.c. Upstream's window holds one EphyEmbed per
# tab and drives navigation, zoom and find through WebKitWebView; that layer
# (ephy-embed.c) is not in this round's component list and is not ported,
# so each tab here holds a plain placeholder page with its own small
# navigation history (a stack of addresses) that the toolbar's
# back/forward/reload actions operate on for real — there is just no actual
# network fetch or page render behind the addresses. `chrome` (EphyWindowChrome)
# controls header-bar visibility exactly as upstream's notify::chrome does.
class Window
  # EphyWindowChrome from lib/ephy-type-builtins, the subset this port's
  # header bar reads (sync_chromes_visibility).
  CHROME_HEADER_BAR = 1 << 0
  CHROME_BOOKMARKS  = 1 << 1
  CHROME_MENU       = 1 << 2
  CHROME_DEFAULT    = CHROME_HEADER_BAR | CHROME_BOOKMARKS | CHROME_MENU

  Page = Struct.new(:widget, :history, :index) do
    def address = history[index]

    def can_go_back? = index > 0

    def can_go_forward? = index < history.length - 1
  end

  def initialize(application:, settings:, downloads_manager: DownloadsManager.new)
    @application = application
    @settings = settings
    @downloads_manager = downloads_manager
    @chrome = CHROME_DEFAULT
    @pages = {}
    @closed_tabs = []
    build_actions
  end

  attr_reader :chrome

  def chrome=(value)
    @chrome = value
    sync_chrome_visibility
  end

  def tab_view = @tab_view ||= TabView.new(settings: @settings)

  def tab_bar = @tab_bar ||= tab_view.attach_tab_bar(Adwaita::TabBar.new)

  def header_bar = @header_bar ||= HeaderBar.new(window: gtk_window, toggle_bookmarks: -> { toggle_bookmarks })

  def action_bar = @action_bar ||= ActionBar.new(tab_view: tab_view, downloads_manager: @downloads_manager)

  def toolbar_view
    @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
      view.add_top_bar(header_bar.widget)
      view.add_top_bar(tab_bar)
      view.add_bottom_bar(action_bar.widget)
      view.content = tab_view.widget
    end
  end

  def tab_overview
    @tab_overview ||= Adwaita::TabOverview.new.tap do |overview|
      overview.view = tab_view.tab_view
      overview.child = toolbar_view
    end
  end

  # Built with no content yet: header_bar (via HeaderBar's "notify::
  # fullscreened" hookup) and everything downstream of it needs this window
  # object to already exist, so the content it eventually holds — which is
  # built from header_bar — cannot be assigned inside this same memoized
  # construction without recursing back into it.
  def gtk_window
    @gtk_window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
      win.title = 'Web'
      win.set_default_size(1000, 700)
      %w[win toolbar tab].each { |name| win.insert_action_group(name, action_group(name)) }
    end
  end

  def widget = gtk_window

  # The window's own content, which a caller may instead nest inside a
  # bigger overlay (a toast overlay, the notification stack) before
  # assigning it to `gtk_window.content` itself.
  def content = tab_overview

  def present
    gtk_window.content = content if gtk_window.content.nil?
    new_tab if tab_view.n_pages.zero?
    gtk_window.present
  end

  def action_group(name) = @action_groups[name]

  # window-commands.c: window_cmd_open_location / new tab, adapted to this
  # round's placeholder page instead of an EphyEmbed.
  def new_tab(address: 'about:blank')
    page = Page.new(placeholder_page, [address], 0)
    index = tab_view.add_tab(page.widget)
    @pages[page.widget] = page
    sync_title(page)
    index
  end

  def close_tab
    selected = tab_view.selected_page
    (@closed_tabs.push(@pages.delete(selected).history); tab_view.close_selected) if selected
  end

  # ephy_session_undo_close_tab: reopens the most recently closed tab with
  # its full history restored, same as upstream replaying the closed tab's
  # EphySessionState back into a fresh EphyEmbed.
  def reopen_closed_tab
    @closed_tabs.pop&.then do |history|
      page = Page.new(placeholder_page, history, history.length - 1)
      index = tab_view.add_tab(page.widget)
      @pages[page.widget] = page
      sync_title(page)
      index
    end
  end

  def can_reopen_closed_tab? = !@closed_tabs.empty?

  # window_cmd_navigation_back / _forward: move within this tab's own
  # history stack and refresh the title widget's address, same as upstream
  # moving the WebKitBackForwardList and letting notify::display-address do
  # it.
  def navigate_back
    with_current_page { |page| (page.index -= 1; sync_title(page)) if page.can_go_back? }
  end

  def navigate_forward
    with_current_page { |page| (page.index += 1; sync_title(page)) if page.can_go_forward? }
  end

  # window_cmd_navigation_new_address: pushes a new address onto the
  # current tab's history, truncating any forward history, as a real
  # navigation would.
  def load_address(address)
    with_current_page do |page|
      page.history = page.history[0..page.index] + [address]
      page.index += 1
      sync_title(page)
    end
  end

  def toggle_fullscreen = (gtk_window.fullscreened = !gtk_window.fullscreened?)

  def show_tab_overview = (tab_overview.open = true)

  def toggle_bookmarks = header_bar.action_bar_end.bookmarks_button.active = !header_bar.action_bar_end.bookmarks_button.active?

  private

  def placeholder_page
    Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'web-browser-symbolic'
      page.title = 'New Tab'
    end
  end

  def with_current_page
    page = @pages[tab_view.selected_page]
    yield page if page
  end

  def sync_title(page)
    header_bar.title_box.reset('Web', page.address)
    navigation_back_action.enabled = page.can_go_back?
    navigation_forward_action.enabled = page.can_go_forward?
  end

  def sync_chrome_visibility
    header_bar.action_bar_start.navigation_box.visible = (@chrome & CHROME_HEADER_BAR) != 0
    header_bar.action_bar_end.show_bookmarks_button = (@chrome & CHROME_BOOKMARKS) != 0
    header_bar.page_menu_button.widget.visible = (@chrome & CHROME_MENU) != 0
  end

  def navigation_back_action = @action_groups['toolbar'].lookup_action('navigation-back')

  def navigation_forward_action = @action_groups['toolbar'].lookup_action('navigation-forward')

  def build_actions
    @action_groups = {
      'win'     => build_win_actions,
      'toolbar' => build_toolbar_actions,
      'tab'     => build_tab_actions,
    }
  end

  def build_win_actions
    Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(simple_action('new-tab') { new_tab })
      group.add_action(simple_action('fullscreen') { toggle_fullscreen })
      group.add_action(simple_action('show-tab-overview') { show_tab_overview })
    end
  end

  def build_toolbar_actions
    Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(simple_action('navigation-back') { navigate_back }.tap { |a| a.enabled = false })
      group.add_action(simple_action('navigation-forward') { navigate_forward }.tap { |a| a.enabled = false })
      group.add_action(simple_action('reload') { with_current_page { |page| sync_title(page) } })
    end
  end

  def build_tab_actions
    Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(simple_action('close') { close_tab })
    end
  end

  def simple_action(name, &block)
    Gio::SimpleAction.new(name).tap { |action| action.signal_connect('activate') { block.call } }
  end
end
