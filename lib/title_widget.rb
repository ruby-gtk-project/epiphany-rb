# frozen_string_literal: true

# TitleWidget is the contract the header bar's centre widget satisfies: it
# shows an address and a security level, and nothing else about it is known to
# the header bar. The location entry and the title box both satisfy it.
#
# Ported from upstream's src/ephy-title-widget.c, a GInterface with an
# `address` and a `security-level` property, plus lib/ephy-security-levels.c,
# whose icon-name mapping every implementation needs. A Ruby module cannot
# install GObject properties, so the interface is a mixin: an implementation
# defines `address`, `address=`, `security_level` and `security_level=`, and
# this module supplies the shared level constants and the icon lookup.
#
module TitleWidget
  # EphySecurityLevel, in order, from lib/ephy-security-levels.h.
  TO_BE_DETERMINED        = :to_be_determined
  NO_SECURITY             = :no_security
  UNACCEPTABLE_CERTIFICATE = :unacceptable_certificate
  STRONG_SECURITY         = :strong_security
  LOCAL_PAGE              = :local_page

  LEVELS = [
    TO_BE_DETERMINED,
    NO_SECURITY,
    UNACCEPTABLE_CERTIFICATE,
    STRONG_SECURITY,
    LOCAL_PAGE,
  ].freeze

  # ephy_security_level_to_icon_name: a local page and an undetermined level
  # show no icon at all.
  ICON_NAMES = {
    TO_BE_DETERMINED         => nil,
    LOCAL_PAGE               => nil,
    NO_SECURITY              => 'channel-insecure-symbolic',
    UNACCEPTABLE_CERTIFICATE => 'channel-insecure-symbolic',
    STRONG_SECURITY          => 'channel-secure-symbolic',
  }.freeze

  def self.icon_name(level) = ICON_NAMES.fetch(level, nil)

  # ephy_security_level_is_secure: strong security and above, which in the
  # enum's order means strong security and local pages.
  def self.secure?(level)
    LEVELS.index(level).to_i >= LEVELS.index(STRONG_SECURITY)
  end

  def security_icon_name = TitleWidget.icon_name(security_level)

  def secure? = TitleWidget.secure?(security_level)
end
