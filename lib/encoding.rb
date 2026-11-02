# frozen_string_literal: true

# TextEncoding is one text encoding the user can pick for a page.
#
# Ported from upstream's embed/ephy-encoding.c and embed/ephy-encoding.h. The
# title carries mnemonic underscores because upstream's menu item used them;
# setting the title derives `title_elided` (underscores stripped) and a
# collation key, which is what the encoding dialog sorts on.
#
# Named TextEncoding, not Encoding: `class Encoding` at the top level would
# reopen Ruby's core Encoding class rather than define a new one.
#
class TextEncoding
  # EphyLanguageGroup from embed/ephy-encoding.h. Note upstream skips bit 11:
  # LG_JAPANESE is 1 << 10 and LG_KOREAN is 1 << 12.
  LG_NONE          = 0
  LG_ARABIC        = 1 << 0
  LG_BALTIC        = 1 << 1
  LG_CAUCASIAN     = 1 << 2
  LG_C_EUROPEAN    = 1 << 3
  LG_CHINESE_TRAD  = 1 << 4
  LG_CHINESE_SIMP  = 1 << 5
  LG_CYRILLIC      = 1 << 6
  LG_GREEK         = 1 << 7
  LG_HEBREW        = 1 << 8
  LG_INDIAN        = 1 << 9
  LG_JAPANESE      = 1 << 10
  LG_KOREAN        = 1 << 12
  LG_NORDIC        = 1 << 13
  LG_PERSIAN       = 1 << 14
  LG_SE_EUROPEAN   = 1 << 15
  LG_THAI          = 1 << 16
  LG_TURKISH       = 1 << 17
  LG_UKRAINIAN     = 1 << 18
  LG_UNICODE       = 1 << 19
  LG_VIETNAMESE    = 1 << 20
  LG_WESTERN       = 1 << 21
  LG_ALL           = 0x3fffff

  attr_reader :encoding, :title, :title_elided, :collation_key, :language_groups

  def initialize(encoding, title, language_groups)
    @encoding = encoding.to_s
    @language_groups = language_groups.to_i
    self.title = title
  end

  def title=(title)
    @title = title.to_s
    @title_elided = elide_underscores(@title)
    @collation_key = @title_elided.unicode_normalize(:nfd).downcase
  end

  # Whether this encoding belongs to any of the groups in `mask`, which is how
  # ephy_encodings_get_encodings filters the "related" part of the menu.
  def in_groups?(mask) = (@language_groups & mask.to_i) != 0

  def ==(other) = other.is_a?(TextEncoding) && other.encoding == @encoding
  alias eql? ==

  def hash = @encoding.hash

  def to_s = @encoding

  private

    # Upstream's elide_underscores: drop one underscore of each run, keeping
    # the character after it, so "Unicode (UTF-_8)" elides to "Unicode (UTF-8)".
    def elide_underscores(original)
      original.each_char.each_with_object(['', false]) do |char, state|
        if !state[1] && char == '_'
          state[1] = true
        else
          state[1] = false
          state[0] += char
        end
      end.first
    end
end
