# frozen_string_literal: true

require_relative 'encoding'
require_relative 'settings'

# TextEncodings is the database of selectable encodings, plus the short list of
# recently used ones the encoding dialog shows first.
#
# A direct port of upstream's embed/ephy-encodings.c: the same encoding_entries
# table in the same order, the same RECENT_MAX of 4, the same "Unknown (%s)"
# fallback for a code that isn't in the table, and the recent list persisted to
# the state schema's recent-encodings key.
#
# Named TextEncodings for the same reason TextEncoding is: Encoding is a core
# Ruby class.
#
class TextEncodings
  RECENT_MAX = 4

  LG = TextEncoding

  # upstream's encoding_entries[], verbatim and in order.
  ENTRIES = [
    ['Arabic (_IBM-864)', 'IBM864', LG::LG_ARABIC],
    ['Arabic (ISO-_8859-6)', 'ISO-8859-6', LG::LG_ARABIC],
    ['Arabic (_MacArabic)', 'x-mac-arabic', LG::LG_ARABIC],
    ['Arabic (_Windows-1256)', 'windows-1256', LG::LG_ARABIC],
    ['Baltic (_ISO-8859-13)', 'ISO-8859-13', LG::LG_BALTIC],
    ['Baltic (I_SO-8859-4)', 'ISO-8859-4', LG::LG_BALTIC],
    ['Baltic (_Windows-1257)', 'windows-1257', LG::LG_BALTIC],
    ['_Armenian (ARMSCII-8)', 'armscii-8', LG::LG_CAUCASIAN],
    ['_Georgian (GEOSTD8)', 'geostd8', LG::LG_CAUCASIAN],
    ['Central European (_IBM-852)', 'IBM852', LG::LG_C_EUROPEAN],
    ['Central European (I_SO-8859-2)', 'ISO-8859-2', LG::LG_C_EUROPEAN],
    ['Central European (_MacCE)', 'x-mac-ce', LG::LG_C_EUROPEAN],
    ['Central European (_Windows-1250)', 'windows-1250', LG::LG_C_EUROPEAN],
    ['Chinese Simplified (_GB18030)', 'gb18030', LG::LG_CHINESE_SIMP],
    ['Chinese Simplified (G_B2312)', 'GB2312', LG::LG_CHINESE_SIMP],
    ['Chinese Simplified (GB_K)', 'x-gbk', LG::LG_CHINESE_SIMP],
    ['Chinese Simplified (_HZ)', 'HZ-GB-2312', LG::LG_CHINESE_SIMP],
    ['Chinese Simplified (_ISO-2022-CN)', 'ISO-2022-CN', LG::LG_CHINESE_SIMP],
    ['Chinese Traditional (Big_5)', 'Big5', LG::LG_CHINESE_TRAD],
    ['Chinese Traditional (Big5-HK_SCS)', 'Big5-HKSCS', LG::LG_CHINESE_TRAD],
    ['Chinese Traditional (_EUC-TW)', 'x-euc-tw', LG::LG_CHINESE_TRAD],
    ['Cyrillic (_IBM-855)', 'IBM855', LG::LG_CYRILLIC],
    ['Cyrillic (I_SO-8859-5)', 'ISO-8859-5', LG::LG_CYRILLIC],
    ['Cyrillic (IS_O-IR-111)', 'ISO-IR-111', LG::LG_CYRILLIC],
    ['Cyrillic (_KOI8-R)', 'KOI8-R', LG::LG_CYRILLIC],
    ['Cyrillic (_MacCyrillic)', 'x-mac-cyrillic', LG::LG_CYRILLIC],
    ['Cyrillic (_Windows-1251)', 'windows-1251', LG::LG_CYRILLIC],
    ['Cyrillic/_Russian (IBM-866)', 'IBM866', LG::LG_CYRILLIC],
    ['Greek (_ISO-8859-7)', 'ISO-8859-7', LG::LG_GREEK],
    ['Greek (_MacGreek)', 'x-mac-greek', LG::LG_GREEK],
    ['Greek (_Windows-1253)', 'windows-1253', LG::LG_GREEK],
    ['Gujarati (_MacGujarati)', 'x-mac-gujarati', LG::LG_INDIAN],
    ['Gurmukhi (Mac_Gurmukhi)', 'x-mac-gurmukhi', LG::LG_INDIAN],
    ['Hindi (Mac_Devanagari)', 'x-mac-devanagari', LG::LG_INDIAN],
    ['Hebrew (_IBM-862)', 'IBM862', LG::LG_HEBREW],
    ['Hebrew (IS_O-8859-8-I)', 'ISO-8859-8-I', LG::LG_HEBREW],
    ['Hebrew (_MacHebrew)', 'x-mac-hebrew', LG::LG_HEBREW],
    ['Hebrew (_Windows-1255)', 'windows-1255', LG::LG_HEBREW],
    ['_Visual Hebrew (ISO-8859-8)', 'ISO-8859-8', LG::LG_HEBREW],
    ['Japanese (_EUC-JP)', 'EUC-JP', LG::LG_JAPANESE],
    ['Japanese (_ISO-2022-JP)', 'ISO-2022-JP', LG::LG_JAPANESE],
    ['Japanese (_Shift-JIS)', 'Shift_JIS', LG::LG_JAPANESE],
    ['Korean (_EUC-KR)', 'EUC-KR', LG::LG_KOREAN],
    ['Korean (_ISO-2022-KR)', 'ISO-2022-KR', LG::LG_KOREAN],
    ['Korean (_JOHAB)', 'x-johab', LG::LG_KOREAN],
    ['Korean (_UHC)', 'x-windows-949', LG::LG_KOREAN],
    ['_Celtic (ISO-8859-14)', 'ISO-8859-14', LG::LG_NORDIC],
    ['_Icelandic (MacIcelandic)', 'x-mac-icelandic', LG::LG_NORDIC],
    ['_Nordic (ISO-8859-10)', 'ISO-8859-10', LG::LG_NORDIC],
    ['_Persian (MacFarsi)', 'x-mac-farsi', LG::LG_PERSIAN],
    ['Croatian (Mac_Croatian)', 'x-mac-croatian', LG::LG_SE_EUROPEAN],
    ['_Romanian (MacRomanian)', 'x-mac-romanian', LG::LG_SE_EUROPEAN],
    ['R_omanian (ISO-8859-16)', 'ISO-8859-16', LG::LG_SE_EUROPEAN],
    ['South _European (ISO-8859-3)', 'ISO-8859-3', LG::LG_SE_EUROPEAN],
    ['Thai (TIS-_620)', 'TIS-620', LG::LG_THAI],
    ['Thai (IS_O-8859-11)', 'iso-8859-11', LG::LG_THAI],
    ['_Thai (Windows-874)', 'windows-874', LG::LG_THAI],
    ['Turkish (_IBM-857)', 'IBM857', LG::LG_TURKISH],
    ['Turkish (I_SO-8859-9)', 'ISO-8859-9', LG::LG_TURKISH],
    ['Turkish (_MacTurkish)', 'x-mac-turkish', LG::LG_TURKISH],
    ['Turkish (_Windows-1254)', 'windows-1254', LG::LG_TURKISH],
    ['Unicode (UTF-_8)', 'UTF-8', LG::LG_UNICODE],
    ['Cyrillic/Ukrainian (_KOI8-U)', 'KOI8-U', LG::LG_UKRAINIAN],
    ['Cyrillic/Ukrainian (Mac_Ukrainian)', 'x-mac-ukrainian', LG::LG_UKRAINIAN],
    ['Vietnamese (_TCVN)', 'x-viet-tcvn5712', LG::LG_VIETNAMESE],
    ['Vietnamese (_VISCII)', 'VISCII', LG::LG_VIETNAMESE],
    ['Vietnamese (V_PS)', 'x-viet-vps', LG::LG_VIETNAMESE],
    ['Vietnamese (_Windows-1258)', 'windows-1258', LG::LG_VIETNAMESE],
    ['Western (_IBM-850)', 'IBM850', LG::LG_WESTERN],
    ['Western (_ISO-8859-1)', 'ISO-8859-1', LG::LG_WESTERN],
    ['Western (IS_O-8859-15)', 'ISO-8859-15', LG::LG_WESTERN],
    ['Western (_MacRoman)', 'x-mac-roman', LG::LG_WESTERN],
    ['Western (_Windows-1252)', 'windows-1252', LG::LG_WESTERN],

    # Upstream sets the language group to 0 for these so they stay out of the
    # "related" part of the encodings menu.
    ['English (_US-ASCII)', 'us-ascii', 0],
    ['Unicode (UTF-_16 BE)', 'UTF-16BE', 0],
    ['Unicode (UTF-1_6 LE)', 'UTF-16LE', 0],
    ['Unicode (UTF-_32 BE)', 'UTF-32BE', 0],
    ['Unicode (UTF-3_2 LE)', 'UTF-32LE', 0],
  ].freeze

  def initialize(settings: nil)
    @settings = settings || Settings.state
    @hash = {}
    @recent = []
    @listeners = []
    load_entries
    load_recent
  end

  # The ::encoding-added signal upstream emits when a new encoding (an unknown
  # code, usually) enters the table.
  def on_encoding_added(&callback)
    @listeners << callback
    callback
  end

  # ephy_encodings_get_encoding: look a code up, optionally minting an
  # "Unknown (code)" entry for one that isn't in the table.
  def encoding(code, add_if_not_found: false)
    @hash.fetch(code.to_s) do
      if add_if_not_found
        add("Unknown (#{code})", code.to_s, 0)
      end
    end
  end

  def all = @hash.values

  def encodings(group_mask) = @hash.values.select { |item| item.in_groups?(group_mask) }

  # ephy_encodings_add_recent: an unknown code is ignored, a known one moves to
  # the front, and the list is truncated to RECENT_MAX before being saved.
  def add_recent(code)
    code.to_s.then do |name|
      if encoding(name)
        @recent.delete(name)
        @recent.unshift(name)
        @recent = @recent.first(RECENT_MAX)
        @settings.set_strv('recent-encodings', @recent)
      end
      @recent
    end
  end

  def recent = @recent.filter_map { |code| encoding(code) }

  private

    def load_entries
      ENTRIES.each { |(title, code, groups)| add(title, code, groups) }
    end

    # Upstream drops duplicates, caps the list at RECENT_MAX and skips codes
    # that aren't in the table, because an invalid entry used to upset the menu.
    def load_recent
      @settings.get_strv('recent-encodings').each do |code|
        if !@recent.include?(code) && @recent.length < RECENT_MAX && !code.empty? && encoding(code)
          @recent << code
        end
      end
    end

    def add(title, code, groups)
      TextEncoding.new(code, title, groups).tap do |item|
        @hash[code] = item
        @listeners.each { |callback| callback.call(item) }
      end
    end
end
