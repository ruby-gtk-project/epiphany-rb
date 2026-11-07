# frozen_string_literal: true

# Ported from src/ephy-action-helper.c
#
# A thin layer over Gio::SimpleAction's sensitivity: several independent
# conditions (no back history, a modal dialog open, lockdown policy, …) can
# each want an action disabled at the same time, and the action should stay
# disabled until every one of them lifts its own flag. Upstream stores a
# bitmask of flags as qdata on the action and keeps `enabled` in sync with
# "the mask is zero"; this port keeps the same mask on the action's Ruby
# object directly, since there is no qdata here.
class ActionHelper
  SENSITIVITY_KEY = :@ephy_action_sensitivity_flags

  # Adds or clears +flags+ (an Integer bitmask) on +action+ and recomputes
  # its enabled state: the action is enabled only once its flag mask is
  # back to zero. Mirrors ephy_action_change_sensitivity_flags.
  def self.change_sensitivity_flags(action, flags, set)
    current = action.instance_variable_get(SENSITIVITY_KEY) || 0
    updated = set ? (current | flags) : (current & ~flags)

    action.instance_variable_set(SENSITIVITY_KEY, updated)
    action.enabled = (updated == 0)
  end
end
