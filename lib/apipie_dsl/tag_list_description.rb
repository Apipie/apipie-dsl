# frozen_string_literal: true

module ApipieDSL
  class TagListDescription
    attr_reader :tags

    def initialize(tags)
      @tags = tags
    end
  end
end
