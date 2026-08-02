# frozen_string_literal: true

module MooTool
  module Models
    # Used to map to a 4CC and its description
    class DescriptorResult
      attr_reader :key, :string_name

      def initialize(key, string_name)
        @key = key
        @string_name = string_name
      end
    end
  end
end
