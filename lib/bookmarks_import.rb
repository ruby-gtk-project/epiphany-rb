# frozen_string_literal: true

require 'cgi'
require 'json'

require_relative 'bookmark'

# BookmarksImport reads bookmarks in, from the port's own storage file at
# startup and from a Netscape HTML or Chrome JSON file the user picks.
#
# Ported from upstream's src/bookmarks/ephy-bookmarks-import.c. The native
# importer reads the four tables BookmarksExport writes, in upstream's order
# and with upstream's checks: a file missing the tags table or the bookmarks
# table is not a valid bookmarks file, while the two order tables are optional.
#
# The HTML importer reproduces upstream's parser, quirks included: the same
# four textual substitutions before parsing, <H3> pushing a folder name onto
# the tag stack and </DL> popping it, a duplicate URL merging its tag into the
# first occurrence while keeping the first title and date, and a title arriving
# in several chunks being appended rather than overwritten. The Chrome importer
# walks the "roots" object's folders and takes every "url" child that is not a
# chrome:// URL.
#
# A bookmark whose URL is already known is not duplicated: the existing one
# gains any tags the imported one brought, which is upstream's
# get_existing_bookmark.
#
module BookmarksImport
  FIREFOX_PROFILES_DIR = '.mozilla/firefox'
  FIREFOX_BOOKMARKS_FILE = 'places.sqlite'
  FIREFOX_BOOKMARKS_MOBILE_FOLDER = 'Mobile Bookmarks'

  # The two error codes upstream's BOOKMARKS_IMPORT_ERROR domain defines.
  class Error < StandardError; end

  class TagsError < Error; end

  class BookmarksError < Error; end

  class << self
    # ephy_bookmarks_import: the manager's own storage file.
    def import(manager, filename)
      unless File.exist?(filename)
        raise BookmarksError, "#{filename} does not exist"
      end

      parse_native(filename).then do |root|
        unless root['tags']
          raise TagsError,
            'File is not a valid Epiphany bookmarks file: missing tags table'
        end

        Array(root['tags']).each { |tag| manager.create_tag(tag) }

        Hash(root['tags-order']).each_value { |entry| manager.tags_order_add_entry(entry) }

        unless root['bookmarks']
          raise BookmarksError,
            'File is not a valid Epiphany bookmarks file: missing bookmarks table'
        end

        manager.add_bookmarks(bookmarks_from_table(root['bookmarks']))

        Hash(root['bookmarks-order']).each_value do |(type, item, index)|
          manager.add_to_bookmarks_order(type, item, index)
        end

        true
      end
    end

    # ephy_bookmarks_import_from_html
    def import_from_html(manager, filename)
      read_html(filename).then do |markup|
        Parser.new.tap { |parser| parse_html(markup, parser) }.then do |parser|
          parser.tags.each { |tag| manager.create_tag(tag) }
          manager.add_bookmarks(html_bookmarks(parser, manager))
          true
        end
      end
    end

    # ephy_bookmarks_import_from_chrome
    def import_from_chrome(manager, filename)
      parse_chrome(filename).then do |root|
        unless root.is_a?(Hash) && root['roots'].is_a?(Hash)
          raise BookmarksError, 'Bookmarks file could not be parsed:'
        end

        [].tap do |bookmarks|
          root['roots'].each_value { |folder| chrome_import_folder(folder, bookmarks, manager) }
        end.then do |bookmarks|
          manager.add_bookmarks(bookmarks)
          true
        end
      end
    end

    # get_existing_bookmark: an already-known URL is not imported again, it
    # just gains whatever tags the imported copy carried.
    def existing_bookmark(manager, url, tags)
      manager.bookmark_by_url(url).tap do |existing|
        if existing
          Array(tags).each do |tag|
            unless existing.tag?(tag)
              existing.add_tag(tag)
            end
          end
        end
      end
    end

    private

      def parse_native(filename)
        JSON.parse(File.read(filename))
      rescue JSON::ParserError => e
        raise BookmarksError, "File is not a valid Epiphany bookmarks file: #{e.message}"
      end

      def bookmarks_from_table(table)
        Hash(table).map do |url, (time_added, title, id, server_time_modified, _is_uploaded, tags)|
          Bookmark.new(
            url,
            title,
            Array(tags),
            id,
          ).tap do |bookmark|
            bookmark.time_added = time_added.to_i
            bookmark.server_time_modified = server_time_modified.to_i
          end
        end
      end

      def read_html(filename)
        File.read(filename)
      rescue SystemCallError => e
        raise BookmarksError, "HTML bookmarks database could not be opened: #{e.message}"
      end

      # Upstream's four substitutions: <DT> and <p> are dropped because they
      # are never closed, bare ampersands are escaped, and <HR> is closed, so
      # the file parses as XML.
      def prepare_html(markup)
        markup
          .gsub('<DT>', '')
          .gsub('<p>', '')
          .gsub('&', '&amp;')
          .gsub('<HR>', '<HR/>')
      end

      def parse_html(markup, parser)
        parser.parse(prepare_html(markup))
      rescue ArgumentError => e
        raise BookmarksError, "HTML bookmarks database could not be parsed: #{e.message}"
      end

      def html_bookmarks(parser, manager)
        parser.urls.filter_map do |url|
          parser.bookmarks.fetch(url).then do |data|
            if existing_bookmark(manager, url, data[:tags].compact)
              nil
            else
              build_html_bookmark(url, data, manager)
            end
          end
        end
      end

      def build_html_bookmark(url, data, manager)
        data[:add_date].to_i.then do |time_added|
          Bookmark.new(
            url,
            data[:title] || url,
            data[:tags].compact,
            Bookmark.generate_random_id(manager),
          ).tap do |bookmark|
            bookmark.time_added = time_added
            bookmark.server_time_modified = time_added
          end
        end
      end

      def parse_chrome(filename)
        JSON.parse(File.read(filename))
      rescue JSON::ParserError, SystemCallError => e
        raise BookmarksError, "Bookmarks file could not be parsed: #{e.message}"
      end

      # chrome_import_folder plus chrome_add_child: folders recurse, "url"
      # children with a title, a URL that is not chrome:// and a date become
      # bookmarks.
      def chrome_import_folder(object, bookmarks, manager)
        if object.is_a?(Hash) && object['type'] == 'folder'
          Array(object['children']).each { |child| chrome_add_child(child, bookmarks, manager) }
        end
      end

      def chrome_add_child(object, bookmarks, manager)
        if object.is_a?(Hash)
          case object['type']
          when 'url' then chrome_add_url(object, bookmarks, manager)
          when 'folder' then chrome_import_folder(object, bookmarks, manager)
          end
        end
      end

      def chrome_add_url(object, bookmarks, manager)
        object['name'].then do |title|
          object['url'].then do |url|
            object['date_added'].then do |time|
              if title && url && time && !url.start_with?('chrome://')
                bookmarks.unshift(
                  chrome_bookmark(
                    title,
                    url,
                    time,
                    manager,
                  ),
                )
              end
            end
          end
        end
      end

      def chrome_bookmark(title, url, time, manager)
        existing_bookmark(manager, url, []).then do |existing|
          if existing
            existing
          else
            new_chrome_bookmark(
              title,
              url,
              time,
              manager,
            )
          end
        end
      end

      def new_chrome_bookmark(title, url, time, manager)
        time.to_i.then do |time_added|
          Bookmark.new(
            url,
            title,
            [],
            Bookmark.generate_random_id(manager),
          ).tap do |bookmark|
            bookmark.time_added = time_added
            bookmark.server_time_modified = time_added
          end
        end
      end
  end

  # The GMarkupParser upstream drives over the prepared HTML. Only three
  # elements matter to it — H3, A and the closing DL — so the markup is
  # tokenised into tags and text runs here rather than pulled through a full
  # XML parser, which Ruby no longer ships by default. The tag stack, the
  # urls_table keyed by URL, the ordered urls array and the "a title may
  # arrive in chunks" handling are all upstream's ParserData.
  class Parser
    # A tag (with an optional leading slash and an attribute list) or a run of
    # text between tags.
    TOKEN = %r{<\s*(/?)\s*([A-Za-z][\w:-]*)((?:[^>"']|"[^"]*"|'[^']*')*)/?>|([^<]+)}.freeze

    ATTRIBUTE = /([A-Za-z_][\w:-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/.freeze

    attr_reader :tags, :urls, :bookmarks

    def initialize
      @tags_stack = []
      @bookmarks = {}
      @tags = []
      @urls = []
      @current = nil
      @read_title = false
      @read_tag = false
    end

    # Feeds every token to the same three handlers upstream's parser installs.
    def parse(markup)
      markup.scan(TOKEN) do |(closing, name, attribute_string, content)|
        if name.nil?
          text(CGI.unescapeHTML(content))
        elsif closing.empty?
          tag_start(name, attributes_of(attribute_string))
        else
          tag_end(name)
        end
      end
      self
    end

    def tag_start(name, attributes)
      case name.upcase
      when 'H3' then @read_tag = true
      when 'A' then start_anchor(attributes)
      end
    end

    def tag_end(name)
      case name.upcase
      when 'H3' then @read_tag = false
      when 'A' then end_anchor
      when 'DL' then @tags_stack.shift
      end
    end

    def text(content)
      if @read_tag
        @tags_stack.unshift(content)
        @tags << content
      end

      if @read_title && @current
        append_title(content)
      end
    end

    private

      def start_anchor(attributes)
        href_of(attributes).then do |href|
          if href
            @read_title = true
            record_anchor(href, add_date_of(attributes))
          end
        end
      end

      def attributes_of(attribute_string)
        attribute_string.to_s.scan(ATTRIBUTE).to_h do |(name, double, single, bare)|
          [name.upcase, CGI.unescapeHTML(double || single || bare || '')]
        end
      end

      def href_of(attributes) = attributes['HREF']

      def add_date_of(attributes) = attributes['ADD_DATE']

      # A duplicate URL merges its tag into the first occurrence and keeps that
      # one's title and date, so the current bookmark is cleared.
      def record_anchor(href, add_date)
        if @bookmarks.key?(href)
          @bookmarks[href][:tags] << @tags_stack.first
          @current = nil
        else
          @bookmarks[href] = { tags: [@tags_stack.first], add_date: add_date, title: nil }
          @urls << href
          @current = @bookmarks[href]
        end
      end

      def end_anchor
        @read_title = false
        @current = nil
      end

      def append_title(content)
        if @current[:title]
          @current[:title] += content
        else
          @current[:title] = content.dup
        end
      end
  end
end
