# frozen_string_literal: true

module MooTool
  module Models::IMG4
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
        { @key => @value }
      end

      def inspect
        to_h.ai
      end
    end
  end
end
