# frozen_string_literal: true

require_relative 'download'

# DownloadsManager keeps the list of downloads for the session, in the
# most-recent-first order upstream's GList prepend gives, and tracks the
# estimated progress across whichever of them are still active.
#
# Ported from embed/ephy-downloads-manager.c. Upstream also acquires a
# GtkApplication session inhibitor (logout/suspend) while any download is
# active; that inhibitor is modeled here as a plain counter and callbacks the
# caller supplies, since the actual inhibit/uninhibit call belongs to
# whichever Gtk::Application owns the running app — not ported yet — and this
# class should not reach out to a global for it.
class DownloadsManager
  def initialize(inhibit: nil, uninhibit: nil)
    @downloads = []
    @inhibitors = 0
    @inhibit = inhibit
    @uninhibit = uninhibit

    @added_handlers = []
    @completed_handlers = []
    @removed_handlers = []
    @progress_handlers = []
    @show_downloads_handlers = []
  end

  def on_download_added(&cb)
    @added_handlers << cb
    cb
  end

  def on_download_completed(&cb)
    @completed_handlers << cb
    cb
  end

  def on_download_removed(&cb)
    @removed_handlers << cb
    cb
  end

  def on_estimated_progress_changed(&cb)
    @progress_handlers << cb
    cb
  end

  def on_show_downloads(&cb)
    @show_downloads_handlers << cb
    cb
  end

  # ephy_downloads_manager_add_download
  def add_download(download)
    return if @downloads.include?(download)

    acquire_session_inhibitor

    @downloads.unshift(download)
    download.on_completed { download_completed(download) }
    download.on_error { |error| download_failed(download, error) }

    @added_handlers.each { |h| h.call(download) }
    notify_progress_changed
  end

  # ephy_downloads_manager_remove_download
  def remove_download(download)
    return unless @downloads.delete(download)

    @removed_handlers.each { |h| h.call(download) }
  end

  # ephy_downloads_manager_has_active_downloads
  def active_downloads? = @downloads.any?(&:active?)

  # ephy_downloads_manager_get_downloads
  def downloads = @downloads.dup

  # ephy_downloads_manager_get_estimated_progress: the average progress of
  # the still-active downloads, or 1 (fully done) when none are active.
  def estimated_progress
    active = @downloads.select(&:active?)
    return 1.0 if active.empty?

    total = active.sum { |d| d.webkit_download.estimated_progress }
    total / active.size
  end

  # ephy_downloads_manager_find_download_by_id
  def find_download_by_id(uid) = @downloads.find { |d| d.uid == uid }

  def show_downloads = @show_downloads_handlers.each(&:call)

  private

    # download_completed_cb
    def download_completed(download)
      notify_progress_changed
      @completed_handlers.each { |h| h.call(download) }
      release_session_inhibitor
    end

    # download_failed_cb: a user-cancelled download is dropped from the list
    # entirely, matching upstream's WEBKIT_DOWNLOAD_ERROR_CANCELLED_BY_USER
    # branch; any other failure just updates progress.
    def download_failed(download, error)
      remove_download(download) if error.respond_to?(:cancelled_by_user?) && error.cancelled_by_user?
      notify_progress_changed
      release_session_inhibitor
    end

    def notify_progress_changed = @progress_handlers.each(&:call)

    def acquire_session_inhibitor
      @inhibitors += 1
      @inhibit&.call if @inhibitors == 1
    end

    def release_session_inhibitor
      @inhibitors -= 1
      @uninhibit&.call if @inhibitors.zero?
    end
end
