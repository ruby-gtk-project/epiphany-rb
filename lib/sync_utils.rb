# frozen_string_literal: true

require 'etc'
require 'json'
require 'securerandom'
require 'socket'
require 'uri'

require_relative 'epiphany/rb/version'
require_relative 'settings'

# SyncUtils is the Firefox Sync helper layer: hex and URL-safe base64 codecs,
# random BSO ids, the client record Sync uploads to describe this device, and
# the typed accessors over the sync schema.
#
# Ported from upstream's lib/ephy-sync-utils.c. The constants come from
# lib/ephy-sync-utils.h, and every settings accessor keeps upstream's
# normalisation: a nil string is stored as "", a negative sync time is stored
# as 0, an empty sync-user reads back as nil rather than "", and reading
# sync-device-name for the first time generates and stores the default name.
#
module SyncUtils
  SECRET_SCHEMA_NAME = 'org.epiphany.SyncSecrets'
  SECRET_ACCOUNT_KEY = 'firefox_account'

  STORAGE_VERSION = 5
  DEVICE_ID_LEN   = 32
  BSO_ID_LEN      = 12
  BATCH_SIZE      = 80
  MAX_BATCHES     = 80

  class << self
    # ephy_sync_utils_encode_hex
    def encode_hex(data) = data.each_byte.map { |byte| format('%02x', byte) }.join

    # ephy_sync_utils_decode_hex
    def decode_hex(hex) = [hex.to_s].pack('H*')

    # ephy_sync_utils_base64_urlsafe_encode: standard base64 with / and +
    # swapped for _ and -, optionally stripped of its = padding. pack('m0') is
    # strict base64 — one line, no trailing newline.
    def base64_urlsafe_encode(data, should_strip: false)
      [data].pack('m0').then do |encoded|
        if should_strip
          encoded.gsub(/\A=+|=+\z/, '')
        else
          encoded
        end
      end.tr('/+', '_-')
    end

    # ephy_sync_utils_base64_urlsafe_decode
    def base64_urlsafe_decode(text, should_fill: false)
      text.to_s.tr('_-', '/+').then do |base64|
        if should_fill
          base64 + ('=' * ((4 - (base64.length % 4)) % 4))
        else
          base64
        end
      end.then { |padded| padded.unpack1('m') }
    end

    # ephy_sync_utils_generate_random_bytes
    def generate_random_bytes(num_bytes) = SecureRandom.bytes(num_bytes)

    # ephy_sync_utils_get_audience: the security origin of a URL, which is what
    # webkit_security_origin_to_string produces — scheme://host[:port].
    def audience(url)
      URI(url.to_s).then do |uri|
        if uri.port && uri.port != uri.default_port
          "#{uri.scheme}://#{uri.host}:#{uri.port}"
        else
          "#{uri.scheme}://#{uri.host}"
        end
      end
    end

    # ephy_sync_utils_get_random_sync_id: BSO_ID_LEN characters of URL-safe
    # base64, generated from ceil(len * 3 / 4) random bytes.
    def random_sync_id
      ((BSO_ID_LEN + 3) / 4 * 3).then do |bytes_len|
        base64_urlsafe_encode(generate_random_bytes(bytes_len))[0, BSO_ID_LEN]
      end
    end

    # ephy_sync_utils_make_client_record
    def make_client_record(device_bso_id, device_id, device_name, version: Epiphany::Rb::Version::VERSION)
      JSON.generate(
        'id'          => device_bso_id,
        'fxaDeviceId' => device_id,
        'name'        => device_name,
        'type'        => 'desktop',
        'version'     => version,
        'protocols'   => ["1.#{STORAGE_VERSION}"],
        'os'          => 'Linux',
        'appPackage'  => 'org.gnome.epiphany',
        'application' => 'Epiphany',
      )
    end

    def device_id = settings.get_string('sync-device-id')

    def device_id=(id)
      settings.set_string('sync-device-id', id.to_s)
    end

    # ephy_sync_utils_get_device_bso_id: the first BSO_ID_LEN characters of the
    # device id, or that many zeroes when there is no device id yet.
    def device_bso_id
      device_id.then do |id|
        if id.empty?
          '0' * BSO_ID_LEN
        else
          id[0, BSO_ID_LEN]
        end
      end
    end

    # ephy_sync_utils_get_device_name: the stored name, or a generated
    # "<user>'s GNOME Web on <host>" which is then stored.
    def device_name
      settings.get_string('sync-device-name').then do |name|
        if name.empty?
          default_device_name.tap { |generated| self.device_name = generated }
        else
          name
        end
      end
    end

    def device_name=(name)
      settings.set_string('sync-device-name', name.to_s)
    end

    def default_device_name = "#{Etc.getlogin}’s GNOME Web on #{Socket.gethostname}"

    # ephy_sync_utils_get_sync_user: an empty user means "not signed in", so
    # upstream hands back NULL rather than the empty string.
    def sync_user
      settings.get_string('sync-user').then do |user|
        unless user.empty?
          user
        end
      end
    end

    def sync_user=(user)
      settings.set_string('sync-user', user.to_s)
    end

    def user_signed_in? = !sync_user.nil?

    def sync_time = settings.get_int64('sync-time')

    def sync_time=(time)
      settings.set_int64('sync-time', [time.to_i, 0].max)
    end

    # Minutes, as upstream notes.
    def sync_frequency = settings.get_uint('sync-frequency')

    def sync_with_firefox? = settings.get_boolean('sync-with-firefox')

    def token_server = settings.get_string('sync-token-server')

    def accounts_server = settings.get_string('sync-accounts-server')

    # The four synchronizable collections each carry an enabled flag, a last
    # sync time and an "is this the first sync" flag, with the same accessors
    # upstream exports one by one.
    %w[bookmarks passwords history extensions].each do |collection|
      define_method(:"#{collection}_sync_enabled?") do
        settings.get_boolean("sync-#{collection}-enabled")
      end

      define_method(:"#{collection}_sync_time") do
        settings.get_int64("sync-#{collection}-time")
      end

      define_method(:"set_#{collection}_sync_time") do |time|
        settings.set_int64("sync-#{collection}-time", time.to_i)
      end

      define_method(:"#{collection}_sync_initial?") do
        settings.get_boolean("sync-#{collection}-initial")
      end

      define_method(:"set_#{collection}_sync_initial") do |is_initial|
        settings.set_boolean("sync-#{collection}-initial", is_initial)
      end
    end

    # Open tabs sync has no initial flag upstream, only enabled and time.
    def open_tabs_sync_enabled? = settings.get_boolean('sync-open-tabs-enabled')

    def open_tabs_sync_time = settings.get_int64('sync-open-tabs-time')

    def open_tabs_sync_time=(time)
      settings.set_int64('sync-open-tabs-time', time.to_i)
    end

    def settings = Settings.sync
  end
end
