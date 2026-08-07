# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a collection of SysCfg entries, typically found within a system configuration payload.
      class SysCfgPayload
        # Initializes a new SysCfgPayload with a list of entries.
        #
        # @param list [Array<SysCfgEntry>] A list of SysCfgEntry objects.
        def initialize(list)
          @values = list
        end

        # Converts all SysCfg entries into a single merged hash.
        #
        # @return [Hash] A hash containing all key-value pairs from the entries.
        def to_h
          @values.map(&:to_h).reduce(&:merge)
        end

        # Provides a string representation of the SysCfg payload hash.
        #
        # @return [String] The inspected hash string.
        def inspect
          to_h.inspect
        end
      end
    end
  end
end
