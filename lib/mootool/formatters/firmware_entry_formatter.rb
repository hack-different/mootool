# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatter to display firmware entries (those with DGST)
    module FirmwareEntryFormatter
      SKIP_KEYS = %i[DGST clas].freeze

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

      def format_other(key, value)
        case value
        when MooTool::Models::Digest
          "#{colorize(key, :symbol)}  " \
          "#{colorize(value.hint, :class).rjust(24)} #{colorize(value.shasum, :digest)}"
        else
          "#{colorize(key, :symbol)}: #{value.ai}"
        end
      end

      def digest_dgst(entry)
        entry.value[:DGST]
      end

      def digest_booleans(entry)
        entry.value.select { |_k, v| [true, false].include?(v) }.map do |key, value|
          color = value ? :trueclass : :falseclass
          colorize(key, color).to_s
        end
      end

      def digest_other(entry)
        entry.value.reject { |k, v| SKIP_KEYS.include?(k) || [true, false].include?(v) }
      end
    end
  end
end
