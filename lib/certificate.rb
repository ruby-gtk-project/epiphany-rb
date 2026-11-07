# frozen_string_literal: true

require 'gcr-rb'
require 'gio2'

# Certificate turns a DER-encoded TLS certificate's fields into the plain
# section/row data the security dialog displays, without building any
# widgets itself — the same model-before-UI split this port keeps for
# Download/DownloadsManager, since src/ephy-certificate-dialog.c's own widget
# tree is not ported yet.
#
# Ported from src/ephy-certificate-dialog.c's create_page / create_section /
# create_section_row, backed by `gcr-rb`'s GObject-Introspection binding of
# libgcr-4 (Gcr::SimpleCertificate), which is the same GCR_API_SUBJECT_TO_CHANGE
# surface upstream itself depends on.
#
# A field's value comes back from the typelib as a GLib::Value wrapping
# whichever GType gcr_certificate_field_get_value_type reports for that
# field — a plain string for most fields, a GLib::Bytes for anything
# upstream renders as a hex dump (serial number, key material, signature).
# `row_value` reproduces upstream's three-way switch on that type.
class Certificate
  Section = Struct.new(:label, :rows)
  Row = Struct.new(:label, :value, :monospace)

  def initialize(der_bytes)
    @certificate = Gcr::SimpleCertificate.new(der_bytes)
  end

  # gcr_certificate_get_issuer_name / get_subject_name, used by title bars
  # and the "who issued this" summary line above the sections.
  def subject_cn = @certificate.subject_cn
  def issuer_cn = @certificate.issuer_cn
  def expiry_date = @certificate.expiry_date
  def key_size = @certificate.key_size

  # gcr_certificate_get_interface_elements, walked the same way
  # create_page/create_section walk it, minus the GtkListBox binding.
  def sections
    @certificate.interface_elements.map do |section|
      Section.new(section.label, section.fields.map { |field| row_for(field) })
    end
  end

  private

    def row_for(field)
      value = field.get_property('value')
      Row.new(field.label, *row_value(value))
    end

    # create_section_row's g_type_is_a chain: a plain string is shown as-is,
    # a GStrv is joined with newlines, and a GBytes (serial numbers, key
    # fingerprints, raw signatures) is hex-dumped and marked monospace the
    # same way upstream adds the "monospace" CSS class.
    def row_value(glib_value)
      raw = glib_value.value
      case raw
      when GLib::Bytes
        [hex_dump(raw.to_s.bytes), true]
      when Array
        [raw.join("\n"), false]
      else
        [raw.to_s, false]
      end
    end

    # bytes_to_display: space-separated uppercase hex, the same format
    # upstream's manual hexc[] lookup produces.
    def hex_dump(bytes) = bytes.map { |byte| format('%02X', byte) }.join(' ')
end
