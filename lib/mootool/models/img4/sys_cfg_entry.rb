# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a SysCfg Key + Value with protection settings
      class SysCfgEntry
        def initialize(input)
          @key = input[0].to_4cc(true)
          @protection = input[1]
          @value = input[2]
        end

        def to_h
          { IMG4.key_name(@key) => @value }
        end

        def inspect
          to_h.ai
        end
      end
    end
  end
end
