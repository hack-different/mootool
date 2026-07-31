# frozen_string_literal: true

module MooTool
  module Models::IMG4
    # A structured instance of a firmware entry tag.  These entries always have a `DGST` for the hash of the payload.
    class FirmwareEntry < MooTool::Models::IMG4::PropertySequence
      def to_h
        { @key => self }
      end
    end
  end
end
