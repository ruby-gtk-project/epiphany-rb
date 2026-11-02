# frozen_string_literal: true

require_relative 'search_engine'
require_relative 'settings'

# SearchEngineManager holds the configured search engines, the default and
# incognito choices, and the bang index behind "!ddg some query".
#
# Ported from upstream's lib/ephy-search-engine-manager.c. The engines load out
# of the main schema's search-engine-providers key, are kept sorted by name
# (upstream is a GListModel the preferences list binds to, so order matters),
# and a bang collision on load resets the later engine's bang exactly as
# upstream warns and does. Deleting the last engine is refused, and deleting
# the default or incognito engine falls back to the first in sorted order.
#
# Saving is explicit, as upstream documents: the preferences UI edits engines
# live and calls save_to_settings when it is done, so the engines and the two
# name keys can never drift apart.
#
class SearchEngineManager
  def initialize(settings: nil)
    @settings = settings || Settings.main
    @engines = []
    @bangs = {}
    @listeners = { 'default-engine' => [], 'incognito-engine' => [], 'items-changed' => [] }
    load_from_settings
  end

  attr_reader :engines

  def default_engine = @default_engine

  def incognito_engine = @incognito_engine

  # The GListModel interface upstream implements.
  def n_items = @engines.length

  def item(position) = @engines[position]

  def each(&block) = @engines.each(&block)

  def connect(signal, &callback)
    @listeners[signal.to_s] ||= []
    @listeners[signal.to_s] << callback
    callback
  end

  def default_engine=(engine)
    assert_known!(engine)
    @default_engine = engine
    notify('default-engine')
  end

  def incognito_engine=(engine)
    assert_known!(engine)
    @incognito_engine = engine
    notify('incognito-engine')
  end

  # ephy_search_engine_manager_add_engine: index the bang, watch it for later
  # changes, then insert and re-sort.
  def add_engine(engine)
    unless engine.bang.empty?
      if @bangs.key?(engine.bang)
        raise ArgumentError, "bang #{engine.bang} is already taken"
      end

      @bangs[engine.bang] = engine
    end

    engine.connect('bang') { |changed, _| reindex_bang(changed) }
    @engines << engine
    @engines.sort_by!(&:name)
    notify(
      'items-changed',
      @engines.index(engine),
      0,
      1,
    )
    engine
  end

  # ephy_search_engine_manager_delete_engine: never leave the manager empty,
  # and promote the first engine when the deleted one was default or incognito.
  def delete_engine(engine)
    if @engines.length <= 1
      raise ArgumentError, 'refusing to delete the last search engine'
    end

    @engines.index(engine).then do |position|
      if position.nil?
        raise ArgumentError, 'engine is not in this manager'
      end

      unless engine.bang.empty?
        @bangs.delete(engine.bang)
      end

      @engines.delete_at(position)

      if engine.equal?(@default_engine)
        self.default_engine = @engines.first
      end

      if engine.equal?(@incognito_engine)
        self.incognito_engine = @engines.first
      end

      notify(
        'items-changed',
        position,
        1,
        0,
      )
      engine
    end
  end

  def find_engine_by_name(engine_name)
    @engines.find { |engine| engine.name == engine_name }
  end

  def bang?(bang) = @bangs.key?(bang.to_s)

  # ephy_search_engine_manager_parse_bang_search: the search URL for a query
  # whose first or last word is a known bang, or nil when it is not a bang
  # search at all, which is the caller's cue to use the default engine.
  def parse_bang_search(search)
    parse_bang_query(search).then do |(query, engine)|
      if engine
        engine.build_search_address(query)
      end
    end
  end

  # ephy_search_engine_manager_parse_bang_suggestions: same, for the
  # suggestions URL. Returns the URL and the engine it belongs to, because the
  # caller needs the engine to label the suggestions.
  def parse_bang_suggestions(search)
    parse_bang_query(search).then do |(query, engine)|
      if engine&.suggestions?
        [engine.build_suggestions_address(query), engine]
      end
    end
  end

  # ephy_search_engine_manager_save_to_settings: the engines plus both name
  # keys, written together. OpenSearch fields are omitted when unset, as
  # upstream omits them from the vardict.
  def save_to_settings
    @settings.set_value('search-engine-providers', @engines.map { |engine| to_vardict(engine) })
    @settings.set_string('default-search-engine', @default_engine.name)
    @settings.set_string('incognito-search-engine', @incognito_engine.name)
  end

  private

    def to_vardict(engine)
      {
        'name' => engine.name,
        'url'  => engine.url,
        'bang' => engine.bang,
      }.tap do |dict|
        if engine.suggestions_url
          dict['suggestions_url'] = engine.suggestions_url
        end
        if engine.opensearch_url
          dict['opensearch_url'] = engine.opensearch_url
        end
      end
    end

    def notify(signal, *args)
      Array(@listeners[signal]).each { |callback| callback.call(self, *args) }
    end

    def assert_known!(engine)
      unless @engines.any? { |known| known.equal?(engine) }
        raise ArgumentError, 'engine must be added to the manager first'
      end
    end

    # notify::bang handler: upstream cannot know the engine's previous bang, so
    # it drops every entry pointing at the engine and re-inserts the new one.
    def reindex_bang(engine)
      @bangs.delete_if { |_, indexed| indexed.equal?(engine) }
      unless engine.bang.empty?
        @bangs[engine.bang] = engine
      end
    end

    def load_from_settings
      @settings.get_string('default-search-engine').then do |default_name|
        @settings.get_string('incognito-search-engine').then do |incognito_name|
          @settings.get_value('search-engine-providers').each do |dict|
            add_from_vardict(dict, default_name, incognito_name)
          end
        end
      end

      if @engines.empty?
        reset_to_defaults
      else
        fill_missing_choices
      end
    end

    def add_from_vardict(dict, default_name, incognito_name)
      SearchEngine.new(
        name:            dict['name'].to_s,
        url:             dict['url'].to_s,
        bang:            dict['bang'].to_s,
        suggestions_url: dict['suggestions_url'],
        opensearch_url:  dict['opensearch_url'],
      ).tap do |engine|
        # Bangs are assumed unique; a duplicate means the settings were edited
        # by hand, so upstream clears the bang rather than refuse to start.
        if @bangs.key?(engine.bang)
          warn "Found bang #{engine.bang} assigned to several search engines. " \
               "The bang for #{engine.name} is hence reset to avoid collision."
          engine.bang = ''
        end

        add_engine(engine)

        if engine.name == default_name
          self.default_engine = engine
        end

        if engine.name == incognito_name
          self.incognito_engine = engine
        end
      end
    end

    def reset_to_defaults
      warn 'Having no search engine is forbidden. Resetting to default ones instead.'
      @settings.reset('search-engine-providers')
      @settings.reset('default-search-engine')
      @settings.reset('incognito-search-engine')
      @bangs = {}
      @engines = []
      load_from_settings
    end

    def fill_missing_choices
      if @default_engine.nil?
        self.default_engine = @engines.first
      end

      if @incognito_engine.nil?
        self.incognito_engine = @engines.first
      end
    end

    # parse_bang_query, upstream's algorithm: look at the last word first so a
    # bang typed at the end wins, then the first word, and return the query
    # with the recognised bangs stripped off. nil means "not a bang search".
    def parse_bang_query(search)
      search.to_s.then do |text|
        if text.strip.empty?
          [nil, nil]
        else
          split_bang_query(text)
        end
      end
    end

    def split_bang_query(text)
      text.split(' ', -1).reject(&:empty?).then do |words|
        if words.length < 2
          [nil, nil]
        else
          strip_bangs(words)
        end
      end
    end

    def strip_bangs(words)
      words.dup.then do |remaining|
        engine = nil

        if @bangs.key?(remaining.last)
          engine = @bangs[remaining.last]
          remaining.pop
        end

        if @bangs.key?(remaining.first)
          # Upstream prefers the bang typed last, so the first word's engine
          # only applies when the last word was not itself a bang.
          engine ||= @bangs[remaining.first]
          remaining.shift
        end

        if engine
          [remaining.join(' '), engine]
        else
          [nil, nil]
        end
      end
    end
end
