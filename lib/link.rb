# frozen_string_literal: true

require 'gtk4'

# Link is the contract for anything that can open an address — the window, the
# location controller, the bookmarks sidebar — plus the modifier-to-flags
# mapping that decides whether a click opens a tab, a window, or neither.
#
# Ported from upstream's src/ephy-link.c, a GInterface carrying one signal,
# ::open-link, whose return value is the embed the address landed in. A Ruby
# module cannot install a GObject signal, so the interface is a mixin: an
# implementation defines `open_link(address, embed, flags)` and this module
# supplies the flags and the modifier mapping every caller shares.
#
module Link
  # EphyLinkFlags from src/ephy-link.h.
  NEW_WINDOW           = 1 << 0
  NEW_TAB              = 1 << 1
  JUMP_TO              = 1 << 2
  NEW_TAB_APPEND_AFTER = 1 << 3
  HOME_PAGE            = 1 << 4
  TYPED                = 1 << 5
  BOOKMARK             = 1 << 6

  # The Gdk modifier bits the mapping tests, as integers: a Gdk::ModifierType
  # is a flags object in the Ruby bindings, so the comparisons go through to_i
  # rather than matching the object.
  SHIFT   = Gdk::ModifierType::SHIFT_MASK.to_i
  CONTROL = Gdk::ModifierType::CONTROL_MASK.to_i
  ALT     = Gdk::ModifierType::ALT_MASK.to_i

  # ephy_link_flags_from_modifiers. A middle click opens a background tab, or a
  # window with Shift; a plain click only opens anything else when Ctrl or Alt
  # is held, and then it jumps to the new tab. Upstream compares the whole
  # modifier state for equality, not bit by bit, so an extra modifier means no
  # flags at all — that is kept here.
  def self.flags_from_modifiers(modifiers, middle_click: false)
    modifiers.to_i.then do |mask|
      if middle_click
        middle_click_flags(mask)
      else
        left_click_flags(mask)
      end
    end
  end

  def self.middle_click_flags(mask)
    case mask
    when SHIFT
      NEW_WINDOW
    when 0, CONTROL
      NEW_TAB | NEW_TAB_APPEND_AFTER
    else
      0
    end
  end

  def self.left_click_flags(mask)
    case mask
    when ALT | SHIFT, CONTROL | SHIFT
      NEW_WINDOW
    when ALT, CONTROL
      NEW_TAB | NEW_TAB_APPEND_AFTER | JUMP_TO
    else
      0
    end
  end

  # ephy_link_open: the one entry point callers use, so the flags stay in one
  # place even though each implementation does its own opening.
  def open(address, embed = nil, flags = 0)
    open_link(address, embed, flags)
  end

  def open_with_modifiers(address, embed, modifiers, middle_click: false)
    open(address, embed, Link.flags_from_modifiers(modifiers, middle_click: middle_click))
  end
end
