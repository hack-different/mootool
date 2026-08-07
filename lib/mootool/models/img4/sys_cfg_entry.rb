# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a single entry in a SysCfg payload, consisting of a key, protection settings, and a value.
      class SysCfgEntry
        # Initializes a new SysCfgEntry from raw input data.
        #
        # @param input [Array] An array containing [key_integer, protection_settings, value_bytes].
        def initialize(input)
          @key = input[0].to_4cc(reverse: true)
          @protection = input[1]
          @value = input[2]
        end

        # Converts the SysCfg entry to a hash.
        #
        # @return [Hash] A hash mapping the human-readable key name to its value.
        def to_h
          { IMG4.key_name(@key) => @value }
        end

        # Provides a human-readable inspection of the SysCfg entry.
        #
        # @return [String] The awesome_print representation.
        def inspect
          to_h.ai
        end
      end
    end
  end
end
