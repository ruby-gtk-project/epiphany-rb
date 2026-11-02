# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog lists every keyboard shortcut the browser binds.
#
# A direct port of upstream's src/resources/gtk/shortcuts-dialog.blp: an
# Adw.ShortcutsDialog with the same six sections — General, Navigation, Tabs,
# Miscellaneous, View, Editing — carrying the same items in the same order with
# the same accelerators. An item with two accelerators keeps both, separated by
# a space, as the blueprint writes them.
#
# The two Navigation items upstream duplicates per text direction (Back and
# Forward swap Left and Right in RTL) carry a direction here, and only the
# items matching the dialog's direction are added.
#
class ShortcutsDialog
  LTR = :ltr
  RTL = :rtl

  SECTIONS = {
    'General'       => [
      ['New Window', '<Primary>N'],
      ['New Incognito Window', '<shift><Primary>N'],
      ['Open File', '<Primary>O'],
      ['Save Page', '<Primary>S'],
      ['Take Screenshot', '<shift><Primary>S'],
      ['Print Page', '<Primary>P'],
      ['Quit', '<Primary>Q'],
      ['Keyboard Shortcuts', '<Primary>question'],
      ['Help', 'F1'],
      ['Open Menu', 'F10'],
      ['Show Downloads List', '<shift><Primary>Y'],
    ],
    'Navigation'    => [
      ['Go to Homepage', '<alt>Home'],
      ['Reload Current Page', 'F5 <Primary>R'],
      ['Reload Bypassing Cache', '<shift>F5 <shift><Primary>R'],
      ['Stop Loading Current Page', 'Escape'],
      ['Go Back to Previous Page', '<alt>Left', LTR],
      ['Go Back to Previous Page', '<alt>Right', RTL],
      ['Go Forward to Next Page', '<alt>Right', LTR],
      ['Go Forward to Next Page', '<alt>Left', RTL],
    ],
    'Tabs'          => [
      ['New Tab', '<Primary>T'],
      ['Close Current Tab', '<Primary>W'],
      ['Reopen Closed Tab', '<shift><Primary>T'],
      ['Go to Next Tab', '<Primary>Page_Down <Primary>Tab'],
      ['Go to Previous Tab', '<Primary>Page_Up <shift><Primary>Tab'],
      ['Move Current Tab to the Left', '<shift><Primary>Page_Up'],
      ['Move Current Tab to the Right', '<shift><Primary>Page_Down'],
      ['Duplicate Current Tab', '<shift><Primary>K'],
      ['View Open Tabs', '<shift><Primary>O'],
    ],
    'Miscellaneous' => [
      ['History', '<Primary>H'],
      ['Clear Website Data', '<Primary><Shift>Delete'],
      ['Preferences', '<Primary>comma'],
      ['Bookmark Current Page', '<Primary>D'],
      ['Show Bookmarks List', '<alt><Primary>D'],
      ['Import Bookmarks', '<Shift><Primary>M'],
      ['Export Bookmarks', '<Shift><Primary>X'],
      ['Toggle Caret Browsing', 'F7'],
    ],
    'View'          => [
      ['Zoom In', '<Primary>plus'],
      ['Zoom Out', '<Primary>minus'],
      ['Reset Zoom', '<Primary>0'],
      ['Fullscreen', 'F11'],
      ['View Page Source', '<Primary>U'],
      ['Toggle Inspector', '<shift><Primary>I F12'],
      ['Toggle Reader Mode', '<alt><Primary>R'],
    ],
    'Editing'       => [
      ['Cut', '<Primary>X'],
      ['Copy', '<Primary>C'],
      ['Paste', '<Primary>V'],
      ['Undo', '<Primary>Z'],
      ['Redo', '<shift><Primary>Z'],
      ['Select All', '<Primary>A'],
      ['Select Page URL', '<Primary>L F6'],
      ['Copy Page URL', '<shift><Primary>C'],
      ['Search With Default Search Engine', '<Primary>K'],
      ['Find', '<Primary>F'],
      ['Next Find Result', '<Primary>G'],
      ['Previous Find Result', '<shift><Primary>G'],
    ],
  }.freeze

  def initialize(direction: LTR)
    @direction = direction
  end

  def build
    dialog.tap do |window|
      SECTIONS.each do |title, items|
        window.add(section(title, items))
      end
    end
  end

  def present(parent)
    build.present(parent)
  end

  def dialog
    @dialog ||= Adwaita::ShortcutsDialog.new.tap do |window|
      window.title = 'Keyboard Shortcuts'
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |group|
        group.title = title
        items.select { |item| applies?(item) }.each do |(label, accelerator, _)|
          group.add(item(label, accelerator))
        end
      end
    end

    # An item with no direction applies in both; one with a direction applies
    # only in that direction, which is how the blueprint splits Back/Forward.
    def applies?(item)
      item[2].nil? || item[2] == @direction
    end

    # Positional, not keyword, arguments — the error a no-argument new raises
    # advertises them as "title: utf8, accelerator: utf8", but passing them as
    # keywords fails and passing them positionally works.
    def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
end
