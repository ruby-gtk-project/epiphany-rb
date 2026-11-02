# frozen_string_literal: true

require 'uri'

require_relative 'settings'

# PermissionsManager stores the per-origin answers to permission prompts, and
# answers "which origins have I allowed or denied this for" for the permissions
# page of the security dialog.
#
# Ported from upstream's lib/ephy-permissions-manager.c. Each origin gets the
# permissions schema relocated to its own path, which is also what makes the
# stored decisions enumerable: upstream walks the GSettings keyfile's groups
# because the GSettings API cannot list settings, and this port walks the same
# per-origin groups in the settings store.
#
# The permitted/denied origin lists are cached per permission type and kept up
# to date on every set, exactly as upstream's two hash tables are.
#
class PermissionsManager
  UNDECIDED = -1
  DENY      = 0
  PERMIT    = 1

  # EphyPermissionType, and the schema key each type reads, from
  # permission_type_to_string.
  KEYS = {
    show_notifications: 'notifications-permission',
    save_password:      'save-password-permission',
    access_location:    'geolocation-permission',
    access_microphone:  'audio-device-permission',
    access_webcam:      'video-device-permission',
    show_ads:           'advertisement-permission',
    autoplay_policy:    'autoplay-permission',
    access_display:     'display-device-permission',
  }.freeze

  # The three types upstream prompts for every time instead of storing. Of
  # these, access_webcam_and_microphone is special: the separate microphone and
  # webcam permissions are stored, the combined one is not.
  UNSTORED = %i[access_webcam_and_microphone website_data_access clipboard].freeze

  TYPES = (KEYS.keys + UNSTORED).freeze

  NICKS = { UNDECIDED => 'undecided', DENY => 'deny', PERMIT => 'allow' }.freeze

  # ephy_permission_is_stored_by_permissions_manager
  def self.stored?(type) = !UNSTORED.include?(type)

  def initialize(settings: nil)
    @settings = settings || Settings.default
    @permitted = {}
    @denied = {}
  end

  # ephy_permissions_manager_get_permission
  def permission(type, origin)
    assert_stored!(type)
    schema_for(origin).get_string(KEYS.fetch(type)).then do |nick|
      NICKS.key(nick) || UNDECIDED
    end
  end

  # ephy_permissions_manager_set_permission: write the decision, then move the
  # origin between the permitted and denied caches to match.
  def set_permission(type, origin, permission)
    assert_stored!(type)
    security_origin(origin).then do |canonical|
      if canonical
        schema_for(canonical).set_string(KEYS.fetch(type), NICKS.fetch(permission))
        recache(type, canonical, permission)
      end
      permission
    end
  end

  # ephy_permissions_manager_get_permitted_origins
  def permitted_origins(type) = matching_origins(type, permit: true)

  # ephy_permissions_manager_get_denied_origins
  def denied_origins(type) = matching_origins(type, permit: false)

  # The enum JSC sees in ephy_permissions_manager_export_to_js_context: the
  # permission values and the permission types a web extension may ask about.
  def self.js_permission_enum = { 'UNDECIDED' => UNDECIDED, 'DENY' => DENY, 'PERMIT' => PERMIT }

  def self.js_permission_type_enum
    {
      'SHOW_NOTIFICATIONS' => TYPES.index(:show_notifications),
      'SAVE_PASSWORD'      => TYPES.index(:save_password),
      'ACCESS_LOCATION'    => TYPES.index(:access_location),
      'ACCESS_MICROPHONE'  => TYPES.index(:access_microphone),
      'ACCESS_WEBCAM'      => TYPES.index(:access_webcam),
      'ACCESS_DISPLAY'     => TYPES.index(:access_display),
      'SHOW_ADS'           => TYPES.index(:show_ads),
    }
  end

  private

    def assert_stored!(type)
      unless self.class.stored?(type)
        raise ArgumentError, "#{type} is not stored by the permissions manager"
      end
    end

    def schema_for(origin) = @settings.permissions_for(origin)

    def recache(type, origin, permission)
      case permission
      when UNDECIDED
        cache(@permitted, type)&.delete(origin)
        cache(@denied, type)&.delete(origin)
      when DENY
        cache(@permitted, type)&.delete(origin)
        add_to_cache(@denied, type, origin)
      when PERMIT
        add_to_cache(@permitted, type, origin)
        cache(@denied, type)&.delete(origin)
      else
        raise ArgumentError, "unknown permission #{permission}"
      end
    end

    # Upstream only touches a cache that already exists, so an origin added
    # before the list was ever asked for does not create a half-filled cache.
    def cache(store, type) = store[type]

    def add_to_cache(store, type, origin)
      if store.key?(type) && !store[type].include?(origin)
        store[type] = [origin] + store[type]
      end
    end

    def matching_origins(type, permit:)
      cache_for(permit).then do |store|
        store.fetch(type) do
          scan_origins(type, permit: permit).tap do |origins|
            unless origins.empty?
              store[type] = origins
            end
          end
        end
      end
    end

    def cache_for(permit)
      if permit
        @permitted
      else
        @denied
      end
    end

    # The keyfile walk upstream does, over this port's per-origin groups: an
    # origin is listed when its stored nick for this permission's key matches
    # the side being asked for.
    def scan_origins(type, permit:)
      wanted_nick(permit).then do |wanted|
        @settings.permission_origins.select do |origin|
          @settings.permissions_for(origin).get_string(KEYS.fetch(type)) == wanted
        end
      end
    end

    def wanted_nick(permit)
      if permit
        'allow'
      else
        'deny'
      end
    end

    # webkit_security_origin_new_for_uri: a URI without a scheme and host is
    # not an origin, and upstream silently does nothing for one.
    def security_origin(origin)
      URI(origin.to_s).then do |uri|
        if uri.scheme && uri.host
          if uri.port && uri.port != uri.default_port
            "#{uri.scheme}://#{uri.host}:#{uri.port}"
          else
            "#{uri.scheme}://#{uri.host}"
          end
        end
      end
    rescue URI::InvalidURIError
      nil
    end
end
