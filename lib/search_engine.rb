# frozen_string_literal: true

require 'json'
require 'soup3'
require 'uri'

require_relative 'suggestion'

# SearchEngine is one search provider: its name, search URL, bang shortcut and,
# when it came from an OpenSearch description, its suggestions URL.
#
# Ported from upstream's lib/ephy-search-engine.c. The setter semantics are
# upstream's: name, url and bang are never nil (they start as empty strings),
# while suggestions_url and opensearch_url stay nil and refuse to be set to an
# empty string. Changing the bang notifies, because SearchEngineManager keeps
# its bang index in sync off that notification.
#
class SearchEngine
  # The error upstream returns through the GTask when suggestions cannot be
  # loaded or parsed.
  class SuggestionsError < StandardError; end

  SUGGESTION_ICON = 'ephy-loupe-plus-symbolic'

  attr_reader :name, :url, :bang, :suggestions_url, :opensearch_url

  def initialize(name: '', url: '', bang: '', suggestions_url: nil, opensearch_url: nil)
    @name = name.to_s
    @url = url.to_s
    @bang = bang.to_s
    @suggestions_url = nil
    @opensearch_url = nil
    @listeners = {}
    self.suggestions_url = suggestions_url
    self.opensearch_url = opensearch_url
  end

  def name=(value)
    value.to_s.then do |new_name|
      unless new_name == @name
        @name = new_name
        notify('name')
      end
    end
  end

  def url=(value)
    value.to_s.then do |new_url|
      unless new_url == @url
        @url = new_url
        notify('url')
      end
    end
  end

  def bang=(value)
    value.to_s.then do |new_bang|
      unless new_bang == @bang
        @bang = new_bang
        notify('bang')
      end
    end
  end

  # Upstream refuses an empty suggestions URL, so an engine without
  # suggestions keeps nil rather than "".
  def suggestions_url=(value)
    unless value.nil? || value.to_s.empty? || value.to_s == @suggestions_url
      @suggestions_url = value.to_s
      notify('suggestions-url')
    end
  end

  def opensearch_url=(value)
    unless value.nil? || value.to_s.empty? || value.to_s == @opensearch_url
      @opensearch_url = value.to_s
      notify('opensearch-url')
    end
  end

  def suggestions? = !@suggestions_url.nil?

  def opensearch? = !@opensearch_url.nil?

  # notify::<property>, which is how the manager watches bangs.
  def connect(property, &callback)
    @listeners[property.to_s] ||= []
    @listeners[property.to_s] << callback
    callback
  end

  # ephy_search_engine_build_search_address
  def build_search_address(search_query) = replace_placeholder(@url, search_query)

  # ephy_search_engine_build_suggestions_address
  def build_suggestions_address(search_query)
    replace_placeholder(@suggestions_url, search_query)
  end

  # ephy_search_engine_build_bang_for_name: the first character of every word
  # plus every later uppercase character, lowercased, behind a "!". Both the
  # space and the opening parenthesis split words, so "Wikipedia (en)" gives
  # "!we" and "duck duck go" gives "!ddg".
  def self.build_bang_for_name(name)
    name.to_s.strip.then do |stripped|
      if stripped.empty?
        ''
      else
        acronym_for(stripped).then do |acronym|
          if acronym.empty?
            ''
          else
            "!#{acronym}"
          end
        end
      end
    end
  end

  def self.acronym_for(stripped)
    stripped.split(/[ (]/).reject(&:empty?).map do |word|
      word[0] + word[1..].to_s.each_char.select { |char| char == char.upcase && char != char.downcase }.join
    end.join.downcase
  end

  # ephy_search_engine_matches_by_autodiscovery_link: the OpenSearch URL
  # matching counts as a match, otherwise the names are compared case-folded.
  def matches_autodiscovery_link?(link)
    if @opensearch_url == link.url
      true
    else
      link.name.to_s.downcase == @name.downcase
    end
  end

  # ephy_search_engine_load_suggestions_async, run synchronously: the Ruby port
  # has no GTask, so the caller decides where this runs. The response shape and
  # every error upstream rejects are checked the same way — a non-array root, a
  # root with fewer than two elements, a non-string first element or a
  # non-array second element is a failure.
  def load_suggestions(built_suggestions_url, user_agent: nil)
    fetch(built_suggestions_url, user_agent).then do |body|
      parse_suggestions(body, built_suggestions_url)
    end
  end

  private

    def notify(property)
      Array(@listeners[property]).each { |callback| callback.call(self, property) }
    end

    # Upstream form-encodes the query through libsoup and then drops the "q="
    # libsoup insists on prefixing, so the encoded query — and not a URL-path
    # encoding — is what lands in place of each %s.
    def replace_placeholder(url, search_query)
      URI.encode_www_form_component(search_query.to_s).then do |encoded|
        url.to_s.gsub('%s', encoded)
      end
    end

    # Fetched through libsoup, same as every other network access in this
    # port (OpensearchEngine, the opensearch autodiscovery download) — not
    # through Ruby's own Net::HTTP, which upstream has no equivalent of and
    # which would duplicate what the soup3 gem already gives this app.
    def fetch(url, user_agent)
      Soup::Message.new('GET', url).then do |message|
        Soup::Session.new.tap do |session|
          if user_agent
            session.user_agent = user_agent
          end
        end.send_and_read(message, nil).to_str.tap do
            unless message.status_code < 400
              raise SuggestionsError,
                "Couldn't load search engine suggestions from #{url}: #{message.status_code}"
            end
          end
      end
    end

    def parse_suggestions(body, suggestions_url)
      if body.nil? || body.empty?
        raise SuggestionsError, "No content provided, length #{body.to_s.length}"
      end

      parse_json(body, suggestions_url).then do |root|
        unless root.is_a?(Array) && root.length >= 2
          raise SuggestionsError,
            "Could not parse JSON suggestions from #{suggestions_url} with JSON #{body}: " \
            'Got empty JSON response or non-array root node or smaller than 2 elements ' \
            'array root node'
        end

        unless root[0].is_a?(String)
          raise SuggestionsError,
            "Could not parse JSON suggestions from #{suggestions_url} with JSON #{body}: " \
            'not a string as first element'
        end

        unless root[1].is_a?(Array)
          raise SuggestionsError,
            "Could not parse JSON suggestions from #{suggestions_url} with JSON #{body}: " \
            'not an array as second element'
        end

        suggestions_for(root[1])
      end
    end

    def parse_json(body, suggestions_url)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise SuggestionsError,
        "Could not parse JSON suggestions from #{suggestions_url} with JSON #{body}: #{e.message}"
    end

    # Upstream skips a suggestion term that isn't a string and labels the rest
    # "<term> — <engine> Search Suggestion".
    def suggestions_for(terms)
      terms.select { |term| term.is_a?(String) }.map do |term|
        "#{term} — #{@name} Search Suggestion".then do |unescaped_title|
          Suggestion.without_subtitle(
            Suggestion.escape_markup(unescaped_title),
            unescaped_title,
            build_search_address(term),
          ).tap { |suggestion| suggestion.icon_name = SUGGESTION_ICON }
        end
      end
    end
end
