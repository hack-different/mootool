# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatter to display firmware entries (those with DGST).
    module FirmwareEntryFormatter
      # Keys to skip during general attribute formatting.
      SKIP_KEYS = %i[DGST clas].freeze

      # Formats a firmware entry by displaying its digest, boolean flags, and other attributes.
      #
      # @param entry [MooTool::Models::IMG4::FirmwareEntry] the firmware entry to format
      # @param _options [Hash] additional options (unused)
      # @return [String] the colorized string representation
      def awesome_firmware_entry(entry, _options = {})
        digest = digest_dgst(entry)
        booleans = digest_booleans(entry)
        other = digest_other(entry)

        results = ["#{colorize('Firmware', :class)} #{colorize(digest.shasum, :digest)} #{booleans.join(' ')}"]
        results += digest.files.map do |file|
          "#{colorize('match', :args)}: #{colorize(file.fullname, :path)}"
        end

        results += other.map { |k, v| format_other(k, v) }

        results.join("\n")
      end

      private

      # Formats miscellaneous attributes of the firmware entry.
      #
      # @param key [Symbol] the attribute name
      # @param value [Object] the attribute value
      # @return [String] the formatted string representation
      def format_other(key, value)
        case value
        when MooTool::Models::Digest
          "#{colorize(key, :symbol)}  " \
          "#{colorize(value.hint, :class).rjust(24)} #{colorize(value.shasum, :digest)}"
        else
          "#{colorize(key, :symbol)}: #{value.ai}"
        end
      end

      # Extracts the main digest from the firmware entry.
      #
      # @param entry [MooTool::Models::IMG4::FirmwareEntry] the entry to extract from
      # @return [MooTool::Models::Digest] the extracted digest
      def digest_dgst(entry)
        entry.value[:DGST]
      end

      # Extracts and formats boolean flags from the firmware entry.
      #
      # @param entry [MooTool::Models::IMG4::FirmwareEntry] the entry to extract from
      # @return [Array<String>] list of colorized boolean flag names
      def digest_booleans(entry)
        entry.value.select { |_k, v| [true, false].include?(v) }.map do |key, value|
          color = value ? :trueclass : :falseclass
          colorize(key, color).to_s
        end
      end

      # Extracts other non-boolean, non-digest attributes from the firmware entry.
      #
      # @param entry [MooTool::Models::IMG4::FirmwareEntry] the entry to extract from
      # @return [Hash] hash of other attributes
      def digest_other(entry)
        entry.value.reject { |k, v| SKIP_KEYS.include?(k) || [true, false].include?(v) }
      end
    end
  end
end
