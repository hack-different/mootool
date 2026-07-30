# frozen_string_literal: true

module MooTool
  module Models
    class FirmwareEntry < MooTool::Models::PropertySequence
      def to_h
        { @key => self }
      end
    end
  end
end
