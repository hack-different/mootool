# frozen_string_literal: true

module MooTool
  module Models::IMG4
    # A class representing a series of KeyValueProperties - mappable into a hash
    class PropertySequence
      include MooTool::Helpers::IMG4

      attr_reader :value, :key

      def initialize(input)
        construction = construct(input.value.first)
        @key = construction[0].to_sym
        value = construction[1]
        case value
        when Array, Hash
          @value = value
        when PropertySequence
          @value = { value.key => value.value }
        end

        return unless @value.is_a?(Array)

        @value = @value.map(&:to_h).reduce({}, :merge)
      end

      def to_h
        { Models::IMG4.key_name(@key) => @value.deep_transform_keys { |key| Models::IMG4.key_name(key) } }
      end

      def inspect
        to_h.ai
      end
    end
  end
end
