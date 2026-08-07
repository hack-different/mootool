# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatter to display Hash/Digests with matching files.
    module DigestFormatter
      # Formats a digest object, including its value, hint, and matching files.
      #
      # @param object [MooTool::Models::Digest] the digest to format
      # @return [String] the colorized string representation
      def awesome_digest(object)
        files = digest_files object
        formatted = if object.integer?
                      colorize(object.inspect, :integer)
                    elsif object.hint
                      properties = object.properties.any? ? " (#{object.properties.join(',')})" : ''
                      "#{colorize(object.hint, :class)} #{colorize(object.inspect, :digest)}#{properties}"
                    else
                      colorize(object.inspect, :digest).to_s
                    end

        files.any? ? "#{formatted}\n#{files.join("\n")}" : formatted
      end

      private

      # Generates a list of colorized file matches for the digest.
      #
      # @param object [MooTool::Models::Digest] the digest containing file matches
      # @return [Array<String>] list of formatted file strings
      def digest_files(object)
        object.files.map do |f|
          "#{colorize('match', :args)}: #{colorize(f.fullname, :path)}"
        end
      end
    end
  end
end
