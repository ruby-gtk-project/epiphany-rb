# frozen_string_literal: true

# OpensearchAutodiscoveryLink is one <link rel="search"> a page advertises: the
# name it gave the search engine and the URL of its OpenSearch XML description
# file.
#
# Ported from upstream's lib/ephy-opensearch-autodiscovery-link.c + .h. Both
# properties are construct-only there (there are no setters, only getters), so
# this is a plain immutable value object.
#
class OpensearchAutodiscoveryLink
  attr_reader :name, :url

  # ephy_opensearch_autodiscovery_link_new
  def initialize(name, url)
    @name = name.to_s
    @url = url.to_s
  end
end
