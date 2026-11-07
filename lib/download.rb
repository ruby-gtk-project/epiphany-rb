# frozen_string_literal: true

require 'fileutils'

require_relative 'settings'

# Download wraps one in-progress or finished download, picking its
# destination filename and remembering what to do with the file once it
# finishes.
#
# Ported from embed/ephy-download.c. `webkit_download` is whatever
# WebKit::Download-shaped object the caller hands in: embed/ephy-web-view.c
# and its WebKit::WebView are not ported yet (no Ruby binding exists yet for
# WebKit's GTK4 main-process WebView — only the web-process-extension side is
# bound by the `webkit-web-process-extension` gem), so this class depends
# only on the narrow surface upstream itself uses on WebKitDownload:
# `destination`, `destination=`, `allow_overwrite?`/`allow_overwrite=`,
# `cancel` and `estimated_progress`.
#
# The three EphyDownloadActionType values from embed/ephy-download.h.
class Download
  ACTION_NONE      = :none
  ACTION_BROWSE_TO = :browse_to
  ACTION_OPEN      = :open

  # download_uid in ephy-download.c: a process-wide counter, one past zero so
  # the first uid is 1 exactly as upstream's starts at 1.
  @next_uid = 1
  class << self
    def next_uid
      @next_uid.tap { @next_uid += 1 }
    end
  end

  attr_reader :uid, :webkit_download, :content_type, :error
  attr_accessor :show_notification, :initiated_by_extension_id, :initiated_by_extension_name

  def initialize(webkit_download, content_type: nil)
    @webkit_download = webkit_download
    @content_type = content_type
    @action = ACTION_NONE
    @uid = self.class.next_uid
    @show_notification = true
    @finished = false
    @error = nil
    @completed_handlers = []
    @error_handlers = []
    @moved_handlers = []
  end

  def on_completed(&callback)
    @completed_handlers << callback
    callback
  end

  def on_error(&callback)
    @error_handlers << callback
    callback
  end

  def on_moved(&callback)
    @moved_handlers << callback
    callback
  end

  # ephy_download_get_destination
  def destination = @webkit_download.destination

  # ephy_download_set_destination
  def destination=(path)
    @webkit_download.destination = path
  end

  # ephy_download_get_action / ephy_download_set_action
  attr_reader :action

  def action=(action)
    @action = action
  end

  # ephy_download_cancel
  def cancel = @webkit_download.cancel

  # ephy_download_is_active
  def active? = !@finished

  # ephy_download_succeeded
  def succeeded? = @finished && @error.nil?

  # ephy_download_failed
  def failed? = @finished && !@error.nil?

  # download_completed_cb / download_failed_cb, as called by whatever owns
  # the underlying WebKitDownload once it reaches webkit's own "finished" or
  # "failed" signal.
  def mark_completed
    @finished = true
    @completed_handlers.each(&:call)
  end

  def mark_failed(error)
    @finished = true
    @error = error
    @error_handlers.each { |h| h.call(error) }
  end

  def mark_moved
    @moved_handlers.each(&:call)
  end

  # ephy_download_do_download_action: upstream opens the finished file with
  # the desktop's handler or reveals it in the file manager. Launching a
  # desktop handler is outside what this port can verify headlessly, so the
  # file-system side (resolving the destination path) is implemented and the
  # actual launch is left to the caller via the block.
  def do_download_action(action = nil, &launcher)
    chosen = action || @action
    case chosen
    when ACTION_NONE
      true
    when ACTION_BROWSE_TO, ACTION_OPEN
      launcher ? launcher.call(destination, chosen) : false
    else
      raise ArgumentError, "unknown download action #{chosen}"
    end
  end

  # set_destination_for_suggested_filename: picks a destination path under
  # `directory` (or the configured downloads directory) for
  # `suggested_filename`, sanitizing it and appending "(n)" the same way
  # upstream's g_file_test loop does when the name is already taken, unless
  # the underlying download allows overwriting.
  def set_destination_for_suggested_filename(suggested_filename, directory: nil)
    dest_dir = directory || self.class.downloads_dir
    FileUtils.mkdir_p(dest_dir)

    name = suggested_filename ? self.class.sanitize_filename(suggested_filename) : self.class.tmp_filename
    path = File.join(dest_dir, name)
    path = self.class.truncate_to_name_max(path)

    unless @webkit_download.respond_to?(:allow_overwrite?) && @webkit_download.allow_overwrite?
      path = self.class.uniquify(path)
    end

    self.destination = path
    true
  end

  # ephy_sanitize_filename: strip path separators and NUL out of a suggested
  # filename so it cannot escape the downloads directory.
  def self.sanitize_filename(name)
    name.to_s.tr('/', '_').delete("\0").then { |cleaned| cleaned.empty? ? tmp_filename : cleaned }
  end

  # ephy_file_tmp_filename's fallback pattern, minus the real temp-file
  # creation (nothing is written until a destination is chosen).
  def self.tmp_filename
    "ephy-download-#{rand(36**6).to_s(36)}"
  end

  # NAME_MAX on the filesystems upstream targets.
  NAME_MAX = 255

  def self.truncate_to_name_max(path)
    basename = File.basename(path)
    return path if basename.bytesize <= NAME_MAX

    File.join(File.dirname(path), basename.byteslice(0, NAME_MAX))
  end

  # Append "(n)" before the extension, the same position
  # webkit_download_set_destination's caller computes from the last dot.
  def self.uniquify(path)
    return path unless File.exist?(path)

    dir = File.dirname(path)
    ext = File.extname(path)
    base = File.basename(path, ext)

    (1..).lazy.map { |i| File.join(dir, "#{base}(#{i})#{ext}") }.find { |candidate| !File.exist?(candidate) }
  end

  # ephy_file_get_downloads_dir, backed by the 'download-dir' setting
  # (default "Downloads", relative to the home directory) rather than
  # GLib's user special dirs, mirroring how Settings already stands in for
  # GSettings elsewhere in this port.
  def self.downloads_dir
    configured = Settings.state.get_string('download-dir')
    if configured.nil? || configured.empty?
      File.join(Dir.home, 'Downloads')
    elsif File.absolute_path?(configured)
      configured
    else
      File.join(Dir.home, configured)
    end
  end
end
