# frozen_string_literal: true

require 'rexml/document'
require 'soup3'

require_relative 'search_engine'

# OpensearchEngine parses an OpenSearch XML description file into a
# SearchEngine.
#
# Ported from upstream's lib/ephy-opensearch-engine.c. Upstream drives a
# GMarkupParser (a SAX-style callback parser) over the description file;
# REXML's DOM is used here instead, since the whole document has to be held
# in memory either way and the DOM makes the <Url><Param/></Url> nesting
# upstream handles with a little state machine much more direct to walk.
# Namespace prefixes are stripped the same way upstream does: by element
# name only, ignoring any "foo:" prefix.
#
class OpensearchEngine
  # The single error class upstream's GError-returning functions collapse to
  # here; every raise below corresponds to one of upstream's g_set_error /
  # g_error_new calls.
  class ParseError < StandardError; end

  # ephy_opensearch_engine_load_from_data
  def self.load_from_data(autodiscovery_link, description_file)
    SearchEngine.new.tap do |engine|
      engine.opensearch_url = autodiscovery_link.url
      parse(engine, description_file)

      if engine.name.empty? || engine.url.empty?
        raise ParseError, "Couldn't create search engine as it did not provide sufficient information!"
      end
    end
  end

  # ephy_opensearch_engine_load_from_link_async + _finish, run synchronously:
  # this port has no GTask, so — as SearchEngine#load_suggestions already
  # does for its own network call — the caller decides where this runs.
  def self.load_from_link(autodiscovery_link, user_agent: nil)
    load_from_data(autodiscovery_link, fetch(autodiscovery_link.url, user_agent))
  end

  def self.fetch(url, user_agent)
    Soup::Message.new('GET', url).then do |message|
      Soup::Session.new.tap do |session|
        if user_agent
          session.user_agent = user_agent.to_s
        end
      end.send_and_read(message, nil).to_str.tap do
        unless message.status_code < 400
          raise ParseError,
            "Couldn't download search engine description file from #{url}: #{message.status_code}"
        end
      end
    end
  end
  private_class_method :fetch

  def self.parse(engine, description_file)
    REXML::Document.new(description_file).root.then do |root|
      if root.nil?
        raise ParseError, 'Empty OpenSearch description file.'
      end

      root.elements.each { |element| parse_element(engine, element) }
    end
  end
  private_class_method :parse

  def self.parse_element(engine, element)
    local_name(element).then do |name|
      if name == 'ShortName'
        engine.name = element.text.to_s.strip
      elsif name == 'Url'
        parse_url(engine, element)
      end
    end
  end
  private_class_method :parse_element

  def self.parse_url(engine, element)
    element.attributes['template'].to_s.then do |template|
      build_url(template, element).then do |url|
        mime_type = element.attributes['type'].to_s
        if mime_type == 'text/html'
          engine.url = url_template_param_substitution(url)
        elsif %w[application/json application/x-suggestions+json].include?(mime_type)
          engine.suggestions_url = url_template_param_substitution(url)
        end
      end
    end
  end
  private_class_method :parse_url

  # <Param name=... value=...> children, inserted into the query string as
  # upstream's xml_start_element_cb does: before the fragment when there is
  # one, otherwise at the end; after an existing "?" when there already is a
  # query string, otherwise as a new one.
  def self.build_url(template, element)
    element.elements.to_a.inject(template.dup) do |url, param|
      if local_name(param) == 'Param'
        insert_param(url, param.attributes['name'].to_s, param.attributes['value'].to_s)
      else
        url
      end
    end
  end
  private_class_method :build_url

  def self.insert_param(url, name, value)
    if url.include?('?')
      query_at = url.rindex('?')
      url[0..query_at] + "#{name}=#{value}&" + url[(query_at + 1)..]
    else
      fragment_at = url.index('#') || url.length
      url[0...fragment_at] + "?#{name}=#{value}" + url[fragment_at..]
    end
  end
  private_class_method :insert_param

  def self.local_name(element)
    element.name.to_s.split(':').last
  end
  private_class_method :local_name

  # url_template_param_substitution: replaces every "{param}" (or optional
  # "{param?}") in the path/query/fragment part of the URL with a known
  # default value, or an empty string when the parameter is optional and
  # unknown. Refuses a template with no {searchTerms}.
  def self.url_template_param_substitution(url_template)
    path_start = find_path_start(url_template)
    prefix = url_template[0...path_start]
    remainder = url_template[path_start..]
    has_search_terms = false

    substituted = remainder.gsub(/\{(\w+)(\?)?\}/) do
      param_name = Regexp.last_match(1)
      optional = !Regexp.last_match(2).nil?
      if param_name == 'searchTerms'
        has_search_terms = true
      end
      replacement = default_param_values[param_name]
      if replacement.nil? && !optional
        raise ParseError, "Found unknown URL template parameter #{param_name} in URL #{url_template}."
      end

      replacement || ''
    end

    unless has_search_terms
      raise ParseError,
        "Parsing of URL template #{url_template} succeeded, but no search terms were found " \
        "so it's not useful as a search engine."
    end

    prefix + substituted
  end
  private_class_method :url_template_param_substitution

  # The OpenSearch spec allows substitution anywhere in the URL, but upstream
  # only allows it from the path onward for safety: the scheme and host are
  # found up to the first "//", then the first of "/", "?" or "#" after that
  # marks where substitution is allowed to start.
  def self.find_path_start(url)
    after_scheme = url.index('//')
    if after_scheme.nil?
      raise ParseError, "The #{url} search engine template URL can't be valid."
    end

    after_scheme += 2
    %w[/ ? #].filter_map { |char| url.index(char, after_scheme) }.min.then do |path_start|
      if path_start.nil?
        raise ParseError, "The #{url} search engine template URL can't be valid."
      end

      path_start
    end
  end
  private_class_method :find_path_start

  # get_default_param_values: the defaults upstream substitutes for known
  # OpenSearch template parameters it doesn't ask the user for. Upstream also
  # reads the user's Pango/GTK language; this port has no widget context to
  # ask, so it falls back to "en" when LANG isn't set.
  def self.default_param_values
    {
      'searchTerms'     => '%s',
      'language'        => ENV.fetch('LANG', 'en').split('.').first.to_s.tr('_', '-'),
      'inputEncoding'   => 'UTF-8',
      'outputEncoding'  => 'UTF-8',
      'referrer:source' => 'firefox',
      'count'           => '20',
      'startIndex'      => '1',
      'startPage'       => '1',
    }
  end
  private_class_method :default_param_values
end
