# frozen_string_literal: true

module MooTool
  module Models::IMG4
    # A structured instance of a firmware entry tag.  These entries always have a `DGST` for the hash of the payload.
    class FirmwareEntry < MooTool::Models::IMG4::PropertySequence
      def initialize(input)
        super
        return unless @value[:clas]
        return if @value[:clas].to_sym == @key

        raise Error,
              'If `clas` is present, it must be a string and match the firmware type'
      end

      def digest
        @value[:DGST]
      end

      def to_h
        { Models::IMG4.key_name(@key) => self }
      end
    end
  end
end
