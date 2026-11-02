# frozen_string_literal: true

require 'cgi'
require 'uri'

# Suggestion is one row of the URL bar's suggestion list: a history entry, a
# bookmark, a search-engine suggestion or an inline completion.
#
# Ported from upstream's lib/ephy-suggestion.c. Upstream subclasses
# DzlSuggestion, which supplies id/title/subtitle/icon-name; those are plain
# attributes here. The three constructors upstream exports are kept as the
# three class methods below, including their differences: the plain one
# decodes and markup-escapes the URI into the subtitle, the custom-subtitle one
# takes the subtitle verbatim, and the no-subtitle one leaves it nil.
#
# The id is the URI, which is what replace_typed_text returns when the row is
# picked, and what the location entry then loads.
#
class Suggestion
  DEFAULT_ICON = 'ephy-webpage-symbolic'

  attr_reader :uri, :title, :unescaped_title
  attr_accessor :subtitle, :icon_name, :secondary_icon_name, :favicon

  # ephy_suggestion_new
  def self.create(title_markup, unescaped_title, uri, is_completion: false)
    new(
      title_markup,
      unescaped_title,
      uri,
      subtitle:      escape_markup(decode_uri(uri)),
      is_completion: is_completion,
    )
  end

  # ephy_suggestion_new_with_custom_subtitle
  def self.with_custom_subtitle(title_markup, unescaped_title, subtitle, uri)
    new(
      title_markup,
      unescaped_title,
      uri,
      subtitle: subtitle,
    )
  end

  # ephy_suggestion_new_without_subtitle
  def self.without_subtitle(title_markup, unescaped_title, uri)
    new(title_markup, unescaped_title, uri)
  end

  # ephy_uri_decode, as far as the suggestion subtitle needs it: percent
  # decoding, leaving anything undecodable as it was.
  def self.decode_uri(uri)
    CGI.unescape(uri.to_s.tr('+', ' ')).then do |decoded|
      if decoded.valid_encoding?
        decoded
      else
        uri.to_s
      end
    end
  rescue ArgumentError
    uri.to_s
  end

  # g_markup_escape_text
  def self.escape_markup(text) = CGI.escapeHTML(text.to_s)

  def initialize(title_markup, unescaped_title, uri, subtitle: nil, is_completion: false)
    @title = title_markup.to_s
    @unescaped_title = unescaped_title.to_s
    @uri = uri.to_s
    @subtitle = subtitle
    @is_completion = !!is_completion
    @icon_name = DEFAULT_ICON
    @secondary_icon_name = nil
    @favicon = nil
  end

  # The id DzlSuggestion stores, which upstream sets to the URI.
  def id = @uri

  def completion? = @is_completion

  # ephy_suggestion_replace_typed_text: picking a row replaces whatever was
  # typed with the suggestion's URI, not its title.
  def replace_typed_text(_typed_text) = @uri

  def ==(other) = other.is_a?(Suggestion) && other.uri == @uri
  alias eql? ==

  def hash = @uri.hash
end
