# frozen_string_literal: true

require 'webkit-web-process-extension'

# WebProcessExtension is the Ruby side of what upstream's
# embed/web-process-extension/ephy-web-process-extension.c registers as
# webkit_web_process_extension_initialize: it is handed the
# WebKit::WebProcessExtension object WebKit creates inside the *web* process
# for a tab, and for every page it creates it relays the one signal upstream
# says there is no other way to get — "the DOM has finished loading" — back
# to the main process as a WebKitUserMessage named "DocumentLoaded"
# (on_document_loaded_cb / on_document_loaded_message_sent_cb).
#
# IMPORTANT, read before wiring this into anything: per the
# `webkit-web-process-extension` gem's own README, "this API is a shared
# library WebKit dlopens inside its own web process, and a Ruby gem in the
# application process cannot be one." There is no `webkit_web_process_extension_initialize`
# entry point a Ruby file can register itself as — WebKit only ever dlopens a
# real C shared library there. So nothing in this process can ever hand this
# class a *real* WebKitWebProcessExtension::WebProcessExtension or
# WebKitWebProcessExtension::WebPage; those only exist inside WebKit's own
# web process, which this port cannot become.
#
# What IS real: every method this class calls
# (WebKitWebProcessExtension::WebProcessExtension#signal_connect,
# WebKitWebProcessExtension::WebPage#signal_connect,
# WebKitWebProcessExtension::UserMessage.new,
# WebKitWebProcessExtension::WebPage#send_message_to_view) is the gem's own
# real GObject-Introspection binding of libwebkitgtk's typelib, not a stub —
# confirmed by constructing bare instances of each class via the gem and
# calling these methods on them (see test/drive_epiphany.rb). The one thing
# confirmed NOT to work is calling `send_message_to_view` on a bare,
# not-WebKit-supplied WebPage: it segfaults, because that method reaches into
# native WebKit page internals no Ruby-constructed object has. That is why
# `message_sender` exists: production code leaves it at its default (the
# real `send_message_to_view` call, which only works when WebKit itself
# supplied the page), while anything exercising this class's wiring
# headlessly must inject a fake.
class WebProcessExtension
  def initialize(extension, message_sender: ->(page, message) { page.send_message_to_view(message) })
    @extension = extension
    @message_sender = message_sender
  end

  # webkit_web_process_extension_initialize's "page-created" connection.
  def attach
    @extension.signal_connect('page-created') { |_ext, page| attach_page(page) }
  end

  private

    # content_script_window_object_cleared_cb's neighbour,
    # on_document_loaded_cb: upstream connects this per-page because WebKit
    # has no signal on the main-process WebView for "DOM finished loading",
    # only one here on the web process's WebPage.
    def attach_page(page)
      page.signal_connect('document-loaded') { notify_document_loaded(page) }
    end

    def notify_document_loaded(page)
      @message_sender.call(page, WebKitWebProcessExtension::UserMessage.new('DocumentLoaded'))
    end
end
