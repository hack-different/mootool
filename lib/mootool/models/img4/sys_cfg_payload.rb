# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a SysCfg Key + Value with protection settings
      class SysCfgPayload
        def initialize(list)
          @values = list
        end

        def to_h
          @values.map(&:to_h).reduce(&:merge)
        end

        def inspect
          to_h.inspect
        end
      end
    end
  end
end
