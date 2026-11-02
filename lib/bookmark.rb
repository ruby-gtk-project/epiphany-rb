# frozen_string_literal: true

require_relative 'sync_utils'

# Bookmark is one bookmarked page: its URL, title, tags and the Firefox Sync
# fields that travel with it.
#
# Ported from upstream's src/bookmarks/ephy-bookmark.c. The Firefox Sync field
# names are upstream's property names, because they are also the JSON keys Sync
# exchanges: bmkUri, parentid, parentName, loadInSidebar. A new bookmark gets
# the same constants upstream sets — type "bookmark", parent "toolbar" named
# "Bookmarks Toolbar", not loaded in the sidebar.
#
# Tags are kept sorted with tags_compare, which pins the Favorites tag first
# and otherwise sorts case-insensitively, falling back to the case-sensitive
# comparison for tags that differ only in case.
#
class Bookmark
  TYPE_VAL            = 'bookmark'
  PARENT_ID_VAL       = 'toolbar'
  PARENT_NAME_VAL     = 'Bookmarks Toolbar'
  LOAD_IN_SIDEBAR_VAL = false

  FAVORITES_TAG = 'Favorites'
  MOBILE_TAG    = 'Mobile'

  attr_reader :url, :title, :id, :tags, :time_added
  attr_accessor :type, :parent_id, :parent_name, :load_in_sidebar, :server_time_modified, :icon

  def initialize(url, title, tags, id)
    @listeners = { 'title' => [], 'bmkUri' => [], 'tag-added' => [], 'tag-removed' => [] }
    @tags = []
    @type = TYPE_VAL
    @parent_id = PARENT_ID_VAL
    @parent_name = PARENT_NAME_VAL
    @load_in_sidebar = LOAD_IN_SIDEBAR_VAL
    @server_time_modified = 0
    @icon = nil
    @id = id.to_s
    @url = url.to_s
    @title = title.to_s
    self.time_added = Bookmark.now
    Array(tags).each { |tag| add_tag(tag) }
  end

  # g_get_real_time: microseconds since the epoch, which is the unit every
  # time_added upstream stores and compares.
  def self.now = (Time.now.to_f * 1_000_000).to_i

  # ephy_bookmark_set_time_added: a negative time means "use now".
  def time_added=(time)
    if time.to_i.negative?
      @time_added = Bookmark.now
    else
      @time_added = time.to_i
    end
  end

  def title=(title)
    @title = title.to_s
    notify('title')
  end

  # Changing the URL invalidates the favicon, as upstream drops the icon and
  # restarts the lookup.
  def url=(url)
    url.to_s.then do |new_url|
      unless new_url == @url
        @url = new_url
        @icon = nil
        notify('bmkUri')
      end
    end
  end

  def id=(id)
    @id = id.to_s
  end

  # notify::title, notify::bmkUri, tag-added and tag-removed, which is what
  # BookmarksManager watches on every bookmark it holds.
  def connect(signal, &callback)
    @listeners[signal.to_s] ||= []
    @listeners[signal.to_s] << callback
    callback
  end

  def disconnect(signal, callback)
    Array(@listeners[signal.to_s]).delete(callback)
  end

  def add_tag(tag)
    tag.to_s.then do |name|
      unless @tags.include?(name)
        @tags << name
        sort_tags
      end
      notify('tag-added', name)
      name
    end
  end

  def remove_tag(tag)
    tag.to_s.then do |name|
      @tags.delete(name)
      notify('tag-removed', name)
      name
    end
  end

  def tag?(tag) = @tags.include?(tag.to_s)

  # ephy_bookmark_is_uploaded: no longer used for Firefox Sync, but the
  # import/export format still carries the flag, so it round-trips as false.
  def uploaded? = false

  # The JSON Firefox Sync exchanges. time-added and icon are not Firefox
  # bookmark properties and upstream's serializer skips them; a nil string is
  # serialised as "".
  def to_sync_json
    {
      'id'            => @id.to_s,
      'type'          => @type.to_s,
      'title'         => @title.to_s,
      'bmkUri'        => @url.to_s,
      'parentid'      => @parent_id.to_s,
      'parentName'    => @parent_name.to_s,
      'loadInSidebar' => @load_in_sidebar,
      'tags'          => @tags,
    }
  end

  def self.from_sync_json(data)
    new(
      data['bmkUri'].to_s,
      data['title'].to_s,
      Array(data['tags']).map(&:to_s),
      data['id'].to_s,
    ).tap do |bookmark|
      bookmark.type = data.fetch('type', TYPE_VAL).to_s
      bookmark.parent_id = data.fetch('parentid', PARENT_ID_VAL).to_s
      bookmark.parent_name = data.fetch('parentName', PARENT_NAME_VAL).to_s
      bookmark.load_in_sidebar = data.fetch('loadInSidebar', LOAD_IN_SIDEBAR_VAL)
    end
  end

  # ephy_bookmark_tags_compare: Favorites first, then case-insensitive, then
  # case-sensitive for tags that differ only in case.
  def self.tags_compare(tag1, tag2)
    if tag1 == tag2
      0
    elsif tag1 == FAVORITES_TAG
      -1
    elsif tag2 == FAVORITES_TAG
      1
    else
      compare_casefolded(tag1, tag2)
    end
  end

  def self.compare_casefolded(tag1, tag2)
    (tag1.to_s.downcase <=> tag2.to_s.downcase).then do |folded|
      if folded.zero?
        tag1.to_s <=> tag2.to_s
      else
        folded
      end
    end
  end

  # ephy_bookmark_bookmarks_compare_func: favourites first, then title
  # case-insensitively, then URL, then newest first.
  def self.bookmarks_compare(bookmark1, bookmark2)
    favourite_order(bookmark1, bookmark2) ||
      nonzero(bookmark1.title.to_s.downcase <=> bookmark2.title.to_s.downcase) ||
      nonzero(bookmark1.url.to_s <=> bookmark2.url.to_s) ||
      (bookmark2.time_added <=> bookmark1.time_added)
  end

  def self.favourite_order(bookmark1, bookmark2)
    if bookmark1.tag?(FAVORITES_TAG) && !bookmark2.tag?(FAVORITES_TAG)
      -1
    elsif !bookmark1.tag?(FAVORITES_TAG) && bookmark2.tag?(FAVORITES_TAG)
      1
    end
  end

  def self.nonzero(result)
    unless result.zero?
      result
    end
  end

  # ephy_bookmark_generate_random_id: a random sync id that no bookmark in
  # `manager` is already using.
  def self.generate_random_id(manager)
    SyncUtils.random_sync_id.then do |id|
      if manager&.bookmark_by_id(id)
        generate_random_id(manager)
      else
        id
      end
    end
  end

  private

    def sort_tags
      @tags.sort! { |a, b| Bookmark.tags_compare(a, b) }
    end

    def notify(signal, *args)
      Array(@listeners[signal]).each { |callback| callback.call(self, *args) }
    end
end
