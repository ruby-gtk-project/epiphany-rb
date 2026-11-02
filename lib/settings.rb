# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'uri'

# Settings holds the same schemas, keys and defaults as upstream's
# data/org.gnome.epiphany.gschema.xml, with the schema and key names from
# lib/ephy-prefs.h and the lookup/relocation behaviour of lib/ephy-settings.c.
#
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory before the app can read a single key.
# Requiring an install step to run the port from a checkout is worse than the
# alternative, so the same schemas, keys, defaults, enum nicks and relocation
# rules are backed by a JSON file under XDG_CONFIG_HOME instead.
#
# Upstream's three relocatable schemas (state, web, webapp) are rooted at
# /org/gnome/epiphany/ for the normal profile and at
# /org/gnome/epiphany/web-apps/<id>/ for a web app; `webapp` only exists in web
# app mode. The permissions schema is relocated per origin, which is what
# PermissionsManager uses.
#
class Settings
  MAIN        = 'org.gnome.Epiphany'
  UI          = 'org.gnome.Epiphany.ui'
  READER      = 'org.gnome.Epiphany.reader'
  WEB         = 'org.gnome.Epiphany.web'
  WEB_APP     = 'org.gnome.Epiphany.webapp'
  STATE       = 'org.gnome.Epiphany.state'
  LOCKDOWN    = 'org.gnome.Epiphany.lockdown'
  SYNC        = 'org.gnome.Epiphany.sync'
  PERMISSIONS = 'org.gnome.Epiphany.permissions'

  # The enum nicks each enum-typed key accepts, in gschema value order.
  ENUMS = {
    'restore-session-policy'       => %w[always crashed],
    'tabs-bar-visibility-policy'   => %w[always more-than-one never],
    'font-style'                   => %w[sans serif],
    'color-scheme'                 => %w[light dark],
    'hardware-acceleration-policy' => %w[always never],
  }.freeze

  # The permission enum is numeric upstream (undecided -1, deny 0, allow 1) and
  # PermissionsManager relies on those values.
  PERMISSION_VALUES = {
    'undecided' => -1,
    'deny'      => 0,
    'allow'     => 1,
  }.freeze

  DEFAULT_SEARCH_ENGINES = [
    {
      'name'            => 'DuckDuckGo',
      'url'             => 'https://duckduckgo.com/?q=%s&t=epiphany&kd=-1',
      'bang'            => '!ddg',
      'opensearch_url'  => 'https://duckduckgo.com/opensearch.xml',
      'suggestions_url' => 'https://duckduckgo.com/ac/?q=%s&type=list',
    },
    {
      'name'            => 'Google',
      'url'             => 'https://www.google.com/search?q=%s',
      'bang'            => '!g',
      'opensearch_url'  => 'https://www.google.com/searchdomaincheck?format=opensearch',
      'suggestions_url' => 'https://www.google.com/complete/search?q=%s&inputencoding=UTF-8&outputencoding=UTF-8&client=firefox',
    },
    {
      'name'            => 'Bing',
      'url'             => 'https://www.bing.com/search?q=%s',
      'bang'            => '!b',
      'suggestions_url' => 'https://www.bing.com/osjson.aspx?query=%s',
    },
  ].freeze

  CONTENT_FILTERS = [
    'https://github.com/bnema/ublock-webkit-filters/releases/latest/download/combined-part1.json',
    'https://github.com/bnema/ublock-webkit-filters/releases/latest/download/combined-part2.json',
  ].freeze

  DEFAULTS = {
    MAIN        => {
      'enable-caret-browsing'          => false,
      'homepage-url'                   => '',
      'default-search-engine'          => 'DuckDuckGo',
      'incognito-search-engine'        => 'DuckDuckGo',
      'search-engine-providers'        => DEFAULT_SEARCH_ENGINES,
      'use-search-suggestions'         => true,
      'new-windows-in-tabs'            => true,
      'warn-on-close-unsubmitted-data' => true,
      'restore-session-policy'         => 'always',
      'restore-session-delaying-loads' => true,
      'content-filters'                => CONTENT_FILTERS,
      'ask-for-default'                => true,
      'start-in-incognito-mode'        => false,
      'active-clear-data-items'        => 5,
    },
    UI          => {
      'expand-tabs-bar'                    => true,
      'bottom-url-bar'                     => false,
      'tabs-bar-visibility-policy'         => 'more-than-one',
      'keep-window-open'                   => false,
      'webkit-features-page'               => false,
      'webkit-features-page-show-internal' => false,
    },
    READER      => {
      'font-style'   => 'sans',
      'color-scheme' => 'light',
    },
    WEB         => {
      'min-font-size'                => 0,
      'use-gnome-fonts'              => true,
      'sans-serif-font'              => 'Sans 12',
      'serif-font'                   => 'Serif 12',
      'monospace-font'               => 'Monospace 12',
      'enable-user-css'              => false,
      'enable-user-js'               => false,
      'enable-spell-checking'        => true,
      'default-encoding'             => 'iso-8859-1',
      'language'                     => ['system'],
      'enable-popups'                => false,
      'enable-cookie-banner'         => false,
      'user-agent'                   => '',
      'enable-adblock'               => true,
      'remember-passwords'           => true,
      'autofill-data'                => false,
      'enable-site-specific-quirks'  => true,
      'enable-itp'                   => true,
      'enable-website-data-storage'  => true,
      'default-zoom-level'           => 1.0,
      'reader-mode-zoom-level'       => 1.0,
      'enable-autosearch'            => true,
      'enable-mouse-gestures'        => false,
      'enable-navigation-gestures'   => true,
      'last-upload-directory'        => '',
      'last-download-directory'      => '',
      'hardware-acceleration-policy' => 'always',
      'ask-on-download'              => false,
      'switch-to-new-tab'            => false,
      'enable-webextensions'         => false,
      'webextensions-active'         => [],
      'show-developer-actions'       => false,
      'always-show-full-url'         => false,
      'auto-open-schemes'            => [],
    },
    WEB_APP     => {
      'additional-urls'         => [],
      'show-navigation-buttons' => false,
      'run-in-background'       => false,
      'system'                  => false,
    },
    STATE       => {
      'download-dir'     => 'Downloads',
      'recent-encodings' => [''],
      'window-position'  => [-1, -1],
      'window-size'      => [-1, -1],
      'is-maximized'     => false,
    },
    LOCKDOWN    => {
      'disable-fullscreen'       => false,
      'disable-arbitrary-url'    => false,
      'disable-bookmark-editing' => false,
      'disable-history'          => false,
      'disable-save-to-disk'     => false,
      'disable-printing'         => false,
      'disable-quit'             => false,
      'disable-context-menu'     => false,
    },
    SYNC        => {
      'sync-token-server'       => 'https://token.services.mozilla.com/1.0/sync/1.5',
      'sync-accounts-server'    => 'https://api.accounts.firefox.com/v1',
      'sync-user'               => '',
      'sync-time'               => 0,
      'sync-device-id'          => '',
      'sync-device-name'        => '',
      'sync-frequency'          => 30,
      'sync-with-firefox'       => true,
      'sync-bookmarks-enabled'  => false,
      'sync-bookmarks-time'     => 0,
      'sync-bookmarks-initial'  => true,
      'sync-passwords-enabled'  => false,
      'sync-passwords-time'     => 0,
      'sync-passwords-initial'  => true,
      'sync-history-enabled'    => false,
      'sync-history-time'       => 0,
      'sync-history-initial'    => true,
      'sync-extensions-enabled' => false,
      'sync-extensions-time'    => 0,
      'sync-extensions-initial' => true,
      'sync-open-tabs-enabled'  => false,
      'sync-open-tabs-time'     => 0,
    },
    PERMISSIONS => {
      'audio-device-permission'   => 'undecided',
      'geolocation-permission'    => 'undecided',
      'notifications-permission'  => 'undecided',
      'save-password-permission'  => 'undecided',
      'video-device-permission'   => 'undecided',
      'display-device-permission' => 'undecided',
      'advertisement-permission'  => 'undecided',
      'autoplay-permission'       => 'undecided',
    },
  }.freeze

  # The schemas ephy-settings.c relocates, in its order, with the path segment
  # it appends and whether it only exists in web app mode.
  RELOCATABLE = [
    [STATE, 'state/', false],
    [WEB, 'web/', false],
    [WEB_APP, 'webapp/', true],
  ].freeze

  # Schema is one schema at one path: the keys it holds, their values, and the
  # callbacks watching them. It stands in for a GSettings object, so its
  # readers and writers are named after the g_settings_get_*/set_* calls the
  # upstream code makes.
  class Schema
    attr_reader :id, :path

    def initialize(id, path, store)
      @id = id
      @path = path
      @store = store
      @listeners = {}
    end

    def defaults = DEFAULTS.fetch(@id)

    def keys = defaults.keys

    def [](key)
      key.to_s.then do |name|
        assert_key!(name)
        @store.read(@path, name) { deep_copy(defaults.fetch(name)) }
      end
    end

    def []=(key, value)
      key.to_s.then do |name|
        assert_key!(name)
        assert_value!(name, value)
        @store.write(@path, name, value)
        notify(name)
        value
      end
    end

    def reset(key)
      key.to_s.then do |name|
        assert_key!(name)
        @store.delete(@path, name)
        notify(name)
        self[name]
      end
    end

    def get_boolean(key) = self[key] == true
    def get_string(key) = self[key].to_s
    def get_int(key) = self[key].to_i
    def get_int64(key) = self[key].to_i
    def get_uint(key) = self[key].to_i
    def get_double(key) = self[key].to_f
    def get_strv(key) = Array(self[key]).map(&:to_s)
    def get_value(key) = self[key]

    def set_boolean(key, value) = self[key] = !!value
    def set_string(key, value) = self[key] = value.to_s
    def set_int(key, value) = self[key] = value.to_i
    def set_int64(key, value) = self[key] = value.to_i
    def set_uint(key, value) = self[key] = value.to_i
    def set_double(key, value) = self[key] = value.to_f
    def set_strv(key, value) = self[key] = Array(value).map(&:to_s)
    def set_value(key, value) = self[key] = value

    # The nick an enum-typed key currently holds, and its index in the enum,
    # which is what g_settings_get_enum returns.
    def get_enum(key) = ENUMS.fetch(key.to_s).index(get_string(key))

    def set_enum(key, index)
      self[key] = ENUMS.fetch(key.to_s).fetch(index)
    end

    # Upstream connects to "changed::<key>"; this is the same subscription.
    def connect(key, &callback)
      @listeners[key.to_s] ||= []
      @listeners[key.to_s] << callback
      callback
    end

    def disconnect(key, callback)
      Array(@listeners[key.to_s]).delete(callback)
    end

    private

      def notify(name)
        Array(@listeners[name]).each { |callback| callback.call(self, name) }
      end

      def assert_key!(name)
        unless defaults.key?(name)
          raise KeyError, "#{@id} has no key #{name}"
        end
      end

      def assert_value!(name, value)
        if ENUMS.key?(name) && !ENUMS.fetch(name).include?(value.to_s)
          raise ArgumentError, "#{name} must be one of #{ENUMS.fetch(name).join(', ')}"
        end
      end

      def deep_copy(value) = Marshal.load(Marshal.dump(value))
  end

  # Store is the JSON file every schema instance reads and writes through. One
  # file holds every path, so a relocated schema (per web app, or per origin for
  # the permissions schema) is just another top-level key.
  class Store
    def initialize(path)
      @path = path
      @values = read_file
    end

    attr_reader :path

    def read(group, key)
      if @values.fetch(group, {}).key?(key)
        @values[group][key]
      else
        yield
      end
    end

    def write(group, key, value)
      @values[group] ||= {}
      @values[group][key] = value
      write_file
      value
    end

    def delete(group, key)
      @values.fetch(group, {}).delete(key)
      write_file
    end

    # The groups that hold at least one stored key, which is how
    # PermissionsManager enumerates the origins it has decisions for — the same
    # job upstream does by walking the GSettings keyfile's groups.
    def groups = @values.keys

    def group(name) = @values.fetch(name, {})

    private

      def read_file
        if File.exist?(@path)
          JSON.parse(File.read(@path))
        else
          {}
        end
      rescue JSON::ParserError
        {}
      end

      def write_file
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, "#{JSON.pretty_generate(@values)}\n")
      end
  end

  class << self
    # The process-wide settings, the equivalent of ephy_settings_get's table.
    def default = @default ||= new

    def reset_default!
      @default = nil
    end

    def main = default.schema(MAIN)
    def ui = default.schema(UI)
    def reader = default.schema(READER)
    def web = default.schema(WEB)
    def web_app = default.schema(WEB_APP)
    def state = default.schema(STATE)
    def lockdown = default.schema(LOCKDOWN)
    def sync = default.schema(SYNC)
    def permissions_for(origin) = default.permissions_for(origin)
  end

  attr_reader :store, :web_app_id

  def initialize(path: nil, web_app_id: nil)
    @web_app_id = web_app_id
    @store = Store.new(path || default_path)
    @schemas = {}
  end

  def web_application? = !@web_app_id.nil?

  # ephy_settings_get: hand back the schema for an id, refusing the webapp
  # schema outside web app mode exactly as upstream's g_error does.
  def schema(id)
    @schemas[id] ||= build_schema(id)
  end

  # The permissions schema relocated to one origin. Upstream builds the path
  # from the origin's protocol, host and port, which is also what makes a
  # stored decision findable again.
  def permissions_for(origin)
    schema_path(PERMISSIONS, "permissions/#{origin_segment(origin)}/").then do |path|
      @schemas[path] ||= Schema.new(PERMISSIONS, path, @store)
    end
  end

  # The origins the permissions schema has stored decisions for, rebuilt from
  # their relocated paths. This is upstream's group_name_to_security_origin:
  # the path's last three segments are the protocol, host and port.
  def permission_origins
    permissions_prefix.then do |prefix|
      @store.groups.filter_map do |group|
        if group.start_with?(prefix)
          origin_from_segment(group.delete_prefix(prefix).chomp('/'))
        end
      end
    end.compact
  end

  def location = @store.path

  # Restores the window geometry the previous run recorded, which upstream
  # reads out of the state schema in ephy-window.c.
  def apply_to(window)
    state_schema = schema(STATE)
    state_schema.get_value('window-size').then do |(width, height)|
      if width.to_i.positive? && height.to_i.positive?
        window.set_default_size(width.to_i, height.to_i)
      end
    end
    if state_schema.get_boolean('is-maximized')
      window.maximize
    end
  end

  def record_geometry(window)
    schema(STATE).tap do |state_schema|
      state_schema.set_value('window-size', [window.default_width, window.default_height])
      state_schema.set_boolean('is-maximized', window.maximized?)
    end
  end

  private

    def build_schema(id)
      unless DEFAULTS.key?(id)
        raise ArgumentError, "Invalid schema #{id} requested"
      end

      if id == WEB_APP && !web_application?
        raise(
          ArgumentError,
          'Epiphany is trying to access web app settings outside web app mode',
        )
      end

      Schema.new(id, schema_path(id, relocation_for(id)), @store)
    end

    def relocation_for(id)
      RELOCATABLE.find { |(schema_id, _, _)| schema_id == id }.then do |entry|
        if entry
          entry[1]
        end
      end
    end

    def base_path
      if web_application?
        "/org/gnome/epiphany/web-apps/#{@web_app_id}/"
      else
        '/org/gnome/epiphany/'
      end
    end

    # A non-relocatable schema keeps its own gschema path; a relocatable one
    # hangs off the profile's base path, as ephy_settings_init builds it.
    def schema_path(id, relocation)
      if relocation
        "#{base_path}#{relocation}"
      else
        "/#{id.tr('.', '/').downcase}/"
      end
    end

    def permissions_prefix = "#{base_path}permissions/"

    # The inverse of origin_segment: protocol/host/port back to an origin
    # string, dropping the port when it is the scheme's default or zero.
    def origin_from_segment(segment)
      segment.split('/').then do |(scheme, host, port)|
        if scheme && host
          build_origin(scheme, host, port.to_i)
        end
      end
    end

    def build_origin(scheme, host, port)
      default_port_for(scheme).then do |default_port|
        if port.zero? || port == default_port
          "#{scheme}://#{host}"
        else
          "#{scheme}://#{host}:#{port}"
        end
      end
    end

    def default_port_for(scheme)
      case scheme
      when 'http' then 80
      when 'https' then 443
      else 0
      end
    end

    # http://example.com:8080 becomes http/example.com/8080, the three path
    # segments upstream's group_name_to_security_origin parses back out.
    def origin_segment(origin)
      URI(origin.to_s).then do |uri|
        [uri.scheme, uri.host, uri.port || 0].join('/')
      end
    rescue URI::InvalidURIError, ArgumentError
      origin.to_s.gsub(%r{[:/]+}, '/')
    end

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.join(Dir.home, '.config')),
        'epiphany-rb',
        'settings.json',
      )
    end
end

