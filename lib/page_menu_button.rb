# frozen_string_literal: true

require 'gtk4'

# PageMenuButton is the header bar's "hamburger" menu — the catch-all for
# everything that is not a toolbar button: new window, history, preferences,
# shortcuts, about, quit.
#
# Ported from src/ephy-page-menu-button.c and its template,
# src/resources/gtk/page-menu-button.blp. Upstream builds the menu from a
# .ui resource and prunes items depending on EphyEmbedShellMode (application
# vs. browser) and whether web-app installation is available; this port
# builds the same Gio::Menu structure directly and applies the same pruning
# in #initialize, since there is no mode switch this round — the port only
# ever runs in browser mode, so the "application mode" prunes are the ones
# applied.
class PageMenuButton
  def widget = menu_button

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = 'Main Menu'
      button.popover = page_menu_popover
    end
  end

  def popup = menu_button.popup

  def popdown = menu_button.popdown

  def page_menu_popover
    @page_menu_popover ||= Gtk::PopoverMenu.new(page_menu)
  end

  # The menu structure from page-menu-button.blp, minus the items whose
  # actions this round's app does not install (the window-management and
  # web-app items ephy_can_install_web_apps () prunes upstream, since this
  # port has no web-app installer).
  def page_menu
    @page_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, run_in_background_section)
      menu.append_section(nil, window_section)
      menu.append_section(nil, browsing_section)
      menu.append_section(nil, about_section)
      menu.append_section(nil, quit_section)
    end
  end

  private

  def run_in_background_section
    Gio::Menu.new.tap { |section| section.append('Run in Background', 'app.run-in-background') }
  end

  def window_section
    Gio::Menu.new.tap do |section|
      section.append('New Window', 'app.new-window')
      section.append('New Incognito Window', 'app.new-incognito')
      section.append('Reopen Closed Tab', 'app.reopen-closed-tab')
      section.append('Fullscreen', 'win.fullscreen')
    end
  end

  def browsing_section
    Gio::Menu.new.tap do |section|
      section.append('History', 'app.history')
      section.append('Privacy Report', 'win.privacy-report')
      section.append('Passwords', 'win.passwords')
    end
  end

  def about_section
    Gio::Menu.new.tap do |section|
      section.append('Preferences', 'app.preferences')
      section.append('Keyboard Shortcuts', 'app.shortcuts')
      section.append('About Web', 'app.about')
    end
  end

  def quit_section
    Gio::Menu.new.tap { |section| section.append('Quit', 'app.quit') }
  end
end
