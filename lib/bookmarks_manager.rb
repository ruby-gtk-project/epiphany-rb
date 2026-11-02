# frozen_string_literal: true

require 'fileutils'

require_relative 'bookmark'
require_relative 'bookmarks_export'
require_relative 'bookmarks_import'
require_relative 'sync_utils'

# BookmarksManager holds every bookmark and tag, in the sorted order the
# bookmarks sidebar binds to, and saves the collection whenever it changes.
#
# Ported from upstream's src/bookmarks/ephy-bookmarks-manager.c. It keeps
# upstream's signals (bookmark-added, bookmark-removed, bookmark-title-changed,
# bookmark-url-changed, bookmark-tag-added, bookmark-tag-removed, tag-created,
# tag-deleted, sorted, items-changed), the Favorites tag seeded at construction
# and undeletable, the bookmarks sorted with Bookmark.bookmarks_compare, the
# tags sorted with Bookmark.tags_compare, and the bookmarks-order and
# tags-order side tables the sidebar's drag reordering writes into.
#
# Upstream persists to bookmarks.gvdb through gvdb-builder. GVDB has no Ruby
# binding, so BookmarksExport writes the same four tables — tags, tags-order,
# bookmarks, bookmarks-order — as JSON instead; see that file for why.
#
class BookmarksManager
  BOOKMARKS_FILE = 'bookmarks.json'

  SIGNALS = %w[
    bookmark-added
    bookmark-removed
    bookmark-title-changed
    bookmark-url-changed
    bookmark-tag-added
    bookmark-tag-removed
    tag-created
    tag-deleted
    sorted
    items-changed
    synchronizable-deleted
    synchronizable-modified
  ].freeze

  attr_reader :filename

  def initialize(filename: nil)
    @filename = filename || File.join(profile_dir, BOOKMARKS_FILE)
    @bookmarks = []
    @tags = [Bookmark::FAVORITES_TAG]
    @bookmarks_order = []
    @tags_order = []
    @watched = {}
    @listeners = SIGNALS.to_h { |signal| [signal, []] }

    unless File.exist?(@filename)
      save
    end

    BookmarksImport.import(self, @filename)
    save(with_bookmarks_order: true, with_tags_order: true)
  end

  def connect(signal, &callback)
    @listeners[signal.to_s] ||= []
    @listeners[signal.to_s] << callback
    callback
  end

  # The GListModel interface upstream implements over the bookmarks sequence.
  def n_items = @bookmarks.length

  def item(position) = @bookmarks[position]

  def bookmarks = @bookmarks

  def tags = @tags

  def bookmarks_order = @bookmarks_order

  def tags_order = @tags_order

  # ephy_bookmarks_manager_add_bookmark
  def add_bookmark(bookmark)
    add_bookmark_internal(bookmark, should_save: true)
    emit('synchronizable-modified', bookmark, false)
    bookmark
  end

  # ephy_bookmarks_manager_add_bookmarks: added without saving between each,
  # because the caller saves once at the end.
  def add_bookmarks(bookmarks)
    Array(bookmarks).each do |bookmark|
      add_bookmark_internal(bookmark, should_save: false)
      emit('synchronizable-modified', bookmark, false)
    end
  end

  # ephy_bookmarks_manager_remove_bookmark
  def remove_bookmark(bookmark)
    emit('synchronizable-deleted', bookmark)
    remove_bookmark_internal(bookmark)
  end

  def bookmark_by_url(url) = @bookmarks.find { |bookmark| bookmark.url == url.to_s }

  def bookmark_by_id(id) = @bookmarks.find { |bookmark| bookmark.id == id.to_s }

  # ephy_bookmarks_manager_create_tag: a no-op for a tag that already exists,
  # so the tag-created signal only fires for genuinely new tags.
  def create_tag(tag)
    tag.to_s.then do |name|
      unless @tags.include?(name)
        @tags << name
        sort_tags
        emit('tag-created', name)
      end
      name
    end
  end

  # ephy_bookmarks_manager_delete_tag: Favorites cannot be deleted, and
  # deleting a tag strips it off every bookmark carrying it.
  def delete_tag(tag)
    tag.to_s.then do |name|
      unless name == Bookmark::FAVORITES_TAG
        @tags.delete(name)
        @bookmarks.each { |bookmark| bookmark.remove_tag(name) }
        emit('tag-deleted', name)
      end
      name
    end
  end

  def tag_exists?(tag) = @tags.include?(tag.to_s)

  # ephy_bookmarks_manager_get_bookmarks_with_tag: a nil tag asks for the
  # untagged bookmarks, which is how the sidebar fills its "no tag" page.
  def bookmarks_with_tag(tag)
    if tag.nil?
      @bookmarks.select { |bookmark| bookmark.tags.empty? }
    else
      @bookmarks.select { |bookmark| bookmark.tag?(tag) }
    end.sort { |a, b| Bookmark.bookmarks_compare(a, b) }
  end

  def bookmarks_with_tag?(tag) = !bookmarks_with_tag(tag).empty?

  # ephy_bookmarks_manager_add_to_bookmarks_order: the (type, item, index)
  # triples, kept sorted by index.
  def add_to_bookmarks_order(type, item, index)
    @bookmarks_order << [type.to_s, item.to_s, index.to_i]
    @bookmarks_order.sort_by! { |(_, _, position)| position }
  end

  def clear_bookmarks_order
    @bookmarks_order = []
  end

  # ephy_bookmarks_manager_tags_order_get_tag: the ordered URLs recorded for
  # one tag, or nil when that tag has no recorded order.
  def tags_order_get_tag(tag)
    @tags_order.find { |(name, _)| name == tag.to_s }.then do |entry|
      if entry
        entry[1].map { |(url, _)| url }
      end
    end
  end

  def tags_order_clear_tag(tag)
    @tags_order.reject! { |(name, _)| name == tag.to_s }
  end

  # ephy_bookmarks_manager_tags_order_add_tag: the URLs are stored with their
  # position, which is the (s a(si)) variant upstream builds.
  def tags_order_add_tag(tag, urls)
    @tags_order << [tag.to_s, Array(urls).each_with_index.map { |url, index| [url.to_s, index] }]
  end

  def tags_order_add_entry(entry)
    @tags_order << entry
  end

  def clear_tags_order
    @tags_order = []
  end

  # ephy_bookmarks_manager_save. Upstream's async save plus its sync wrapper
  # collapse into one call here, because BookmarksExport writes the file
  # directly rather than through a GTask.
  def save(with_bookmarks_order: false, with_tags_order: false)
    BookmarksExport.export(
      self,
      @filename,
      with_bookmarks_order: with_bookmarks_order,
      with_tags_order:      with_tags_order,
    )
  end

  # The collection name Firefox Sync stores bookmarks under, which depends on
  # whether the user syncs with Firefox or only between Epiphany profiles.
  def collection_name
    if SyncUtils.sync_with_firefox?
      'bookmarks'
    else
      'ephy-bookmarks'
    end
  end

  def initial_sync? = SyncUtils.bookmarks_sync_initial?

  def initial_sync=(is_initial)
    SyncUtils.set_bookmarks_sync_initial(is_initial)
  end

  def sync_time = SyncUtils.bookmarks_sync_time

  def sync_time=(time)
    SyncUtils.set_bookmarks_sync_time(time)
  end

  # EphySynchronizableManagerInterface's merge: the initial merge reconciles
  # the whole remote collection against the local one, the regular merge
  # applies the deletions and updates since the last sync. Both return the
  # bookmarks to upload.
  def merge(is_initial, remotes_deleted, remotes_updated)
    if is_initial
      handle_initial_merge(remotes_updated)
    else
      handle_regular_merge(remotes_updated, remotes_deleted)
    end
  end

  private

    def profile_dir
      File.join(
        ENV.fetch('XDG_DATA_HOME', File.join(Dir.home, '.local', 'share')),
        'epiphany-rb',
      ).tap { |dir| FileUtils.mkdir_p(dir) }
    end

    def emit(signal, *args)
      Array(@listeners[signal]).each { |callback| callback.call(self, *args) }
    end

    def sort_tags
      @tags.sort! { |a, b| Bookmark.tags_compare(a, b) }
    end

    def add_bookmark_internal(bookmark, should_save:)
      @bookmarks << bookmark
      @bookmarks.sort! { |a, b| Bookmark.bookmarks_compare(a, b) }
      @bookmarks.index(bookmark).then do |position|
        emit(
          'items-changed',
          position,
          0,
          1,
        )
      end
      emit('bookmark-added', bookmark)
      watch_bookmark(bookmark)

      if should_save
        save
      end
    end

    # Upstream removes the bookmark from the list *before* emitting
    # bookmark-removed, because handlers expect it to be gone already.
    def remove_bookmark_internal(bookmark)
      @bookmarks.index { |held| held.id == bookmark.id }.then do |position|
        if position
          @bookmarks.delete_at(position)
          emit(
            'items-changed',
            position,
            1,
            0,
          )
          emit('bookmark-removed', bookmark)
          save
          unwatch_bookmark(bookmark)
        end
        bookmark
      end
    end

    def watch_bookmark(bookmark)
      @watched[bookmark.id] = {
        'title'       => bookmark.connect('title') { |item| emit('bookmark-title-changed', item) },
        'bmkUri'      => bookmark.connect('bmkUri') { |item| emit('bookmark-url-changed', item) },
        'tag-added'   => bookmark.connect('tag-added') { |item, tag| emit('bookmark-tag-added', item, tag) },
        'tag-removed' => bookmark.connect('tag-removed') { |item, tag| emit('bookmark-tag-removed', item, tag) },
      }
    end

    def unwatch_bookmark(bookmark)
      @watched.delete(bookmark.id).then do |handlers|
        Hash(handlers).each { |signal, handler| bookmark.disconnect(signal, handler) }
      end
    end

    def copy_tags_from(dest, source)
      source.tags.each { |tag| dest.add_tag(tag) }
    end

    def create_tags_from(bookmark)
      bookmark.tags.each { |tag| create_tag(tag) }
    end

    # Upstream ignores anything that is not a plain bookmark, and anything
    # filed under "unfiled"; a "mobile" parent gains the Mobile tag, and a
    # remote bookmark with no time added gets one.
    def mergeable?(remote)
      remote.type == Bookmark::TYPE_VAL && remote.parent_id != 'unfiled'
    end

    def prepare_remote(remote)
      if remote.parent_id == 'mobile' && !remote.tag?(Bookmark::MOBILE_TAG)
        remote.add_tag(Bookmark::MOBILE_TAG)
      end

      if remote.time_added.zero?
        remote.time_added = Bookmark.now
      end
    end

    def handle_initial_merge(remote_bookmarks)
      [].tap do |dont_upload|
        Array(remote_bookmarks).select { |remote| mergeable?(remote) }.each do |remote|
          prepare_remote(remote)
          merge_initial_bookmark(remote, dont_upload)
          create_tags_from(remote)
        end
        save
      end.then do |dont_upload|
        @bookmarks.reject { |bookmark| dont_upload.include?(bookmark.id) }
      end
    end

    def merge_initial_bookmark(remote, dont_upload)
      bookmark_by_id(remote.id).then do |by_id|
        if by_id
          merge_initial_by_id(by_id, remote, dont_upload)
        else
          merge_initial_by_url(remote, dont_upload)
        end
      end
    end

    def merge_initial_by_id(local, remote, dont_upload)
      if local.url == remote.url
        # Same id, same url: merge the tags and reupload.
        copy_tags_from(local, remote)
        local.server_time_modified = remote.server_time_modified
      else
        # Same id, different url: keep both, and give the local one a new id.
        local.id = SyncUtils.random_sync_id
        add_bookmark_internal(remote, should_save: false)
        dont_upload << remote.id
      end
    end

    def merge_initial_by_url(remote, dont_upload)
      bookmark_by_url(remote.url).then do |by_url|
        if by_url
          # Different id, same url: keep the remote id, merge tags, reupload.
          by_url.id = remote.id
          copy_tags_from(by_url, remote)
          by_url.server_time_modified = remote.server_time_modified
        else
          # Different id, different url: the remote bookmark is new here.
          add_bookmark_internal(remote, should_save: false)
          dont_upload << remote.id
        end
      end
    end

    def handle_regular_merge(updated_bookmarks, deleted_bookmarks)
      Array(deleted_bookmarks).each do |remote|
        bookmark_by_id(remote.id).then do |local|
          if local
            remove_bookmark_internal(local)
          end
        end
      end

      [].tap do |to_upload|
        Array(updated_bookmarks).select { |remote| mergeable?(remote) }.each do |remote|
          prepare_remote(remote)
          merge_regular_bookmark(remote, to_upload)
          create_tags_from(remote)
        end
        save
      end
    end

    def merge_regular_bookmark(remote, to_upload)
      bookmark_by_id(remote.id).then do |by_id|
        if by_id
          # Same id: the remote bookmark wins outright.
          remove_bookmark_internal(by_id)
          add_bookmark_internal(remote, should_save: false)
        else
          merge_regular_by_url(remote, to_upload)
        end
      end
    end

    def merge_regular_by_url(remote, to_upload)
      bookmark_by_url(remote.url).then do |by_url|
        if by_url
          by_url.id = remote.id
          copy_tags_from(by_url, remote)
          by_url.server_time_modified = remote.server_time_modified
          to_upload << by_url
        else
          add_bookmark_internal(remote, should_save: false)
        end
      end
    end
end
