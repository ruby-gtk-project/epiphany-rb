# frozen_string_literal: true

require 'cgi'
require 'fileutils'
require 'json'

# BookmarksExport writes the bookmark collection out, either as the port's own
# storage format or as a Netscape bookmarks HTML file.
#
# Ported from upstream's src/bookmarks/ephy-bookmarks-export.c, which branches
# on the filename suffix: a .gvdb filename gets the four-table GVDB database
# the manager reloads at startup, anything else gets the HTML file other
# browsers import.
#
# GVDB is a GLib-internal format with no Ruby binding, so the native side
# writes the same four tables — tags, tags-order, bookmarks, bookmarks-order —
# as JSON, keyed and shaped exactly as upstream's tables are: a bookmark is
# keyed by its URL and holds (time_added, title, id, server_time_modified,
# is_uploaded, tags); a bookmarks-order entry is keyed "type:item" and holds
# (type, item, index); a tags-order entry is keyed by tag and holds the tag
# with its (url, index) pairs. The HTML side is byte-for-byte upstream's.
#
module BookmarksExport
  HTML_HEADER = <<~HTML
    <!DOCTYPE NETSCAPE-Bookmark-file-1>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
    <TITLE>Bookmarks</TITLE>
    <H1>Epiphany Bookmarks</H1>
    <DL><p>
    <DT><H3>Epiphany</H3>
    <DL><p>
  HTML

  class << self
    def export(manager, filename, with_bookmarks_order: false, with_tags_order: false)
      if filename.to_s.end_with?('.json')
        write(filename, to_json(manager, with_bookmarks_order, with_tags_order))
      else
        write(filename, to_html(manager))
      end
    end

    # The HTML a bookmark becomes, with its tags joined by ", " in a TAGS
    # attribute. Nothing reads that attribute back: upstream's own HTML
    # importer takes its tags from the folder headings, so a re-import of this
    # file tags everything "Epiphany" after the single <H3> heading above.
    def to_html(manager)
      manager.bookmarks.each_with_object(HTML_HEADER.dup) do |bookmark, html|
        html << format(
          %(<DT><A HREF="%s" ADD_DATE="%d" TAGS="%s">%s</A>\n),
          bookmark.url,
          bookmark.time_added,
          bookmark.tags.join(', '),
          bookmark.title,
        )
      end + "</DL>\n"
    end

    def to_json(manager, with_bookmarks_order, with_tags_order)
      {}.tap do |root|
        if with_tags_order
          root['tags-order'] = tags_order_table(manager)
        end

        root['tags'] = manager.tags

        if with_bookmarks_order
          root['bookmarks-order'] = bookmarks_order_table(manager)
        end

        root['bookmarks'] = bookmarks_table(manager)
      end.then { |root| "#{JSON.pretty_generate(root)}\n" }
    end

    private

      def bookmarks_table(manager)
        manager.bookmarks.to_h do |bookmark|
          [
            bookmark.url,
            [
              bookmark.time_added,
              bookmark.title,
              bookmark.id,
              bookmark.server_time_modified,
              bookmark.uploaded?,
              bookmark.tags,
            ],
          ]
        end
      end

      def bookmarks_order_table(manager)
        manager.bookmarks_order.to_h do |(type, item, index)|
          ["#{type}:#{item}", [type, item, index]]
        end
      end

      def tags_order_table(manager)
        manager.tags_order.to_h do |(tag, urls)|
          [tag, [tag, urls]]
        end
      end

      def write(filename, contents)
        FileUtils.mkdir_p(File.dirname(filename))
        File.write(filename, contents)
        true
      end
  end
end
