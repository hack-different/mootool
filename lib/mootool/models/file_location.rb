# frozen_string_literal: true

module MooTool
  module Models
    # Represents a specific file on disk and its cryptographic hashes.
    class FileLocation
      # @return [String] The directory location of the file.
      # @return [String] The name of the file.
      attr_accessor :location, :filename

      # Initializes a new FileLocation instance.
      #
      # @param location [String] The directory path.
      # @param filename [String] The file name.
      # @param hashes [MooTool::Models::Digest, String, Array, nil] Initial hashes for the file.
      def initialize(location, filename, hashes = nil)
        @location = location
        @filename = filename
        case hashes
        when MooTool::Models::Digest
          @hashes = [hashes]
        when String
          [MooTool::Models::Digest.create(hashes)]
        when Array
          @hashes = hashes.map { |h| MooTool::Models::Digest.create(h) }
        end
      end

      # Checks if the file has any associated hashes.
      #
      # @return [Boolean] True if hashes are present, false otherwise.
      def hashed?
        @hashes&.any?
      end

      # Returns the full path to the file.
      #
      # @return [String] The combined path and filename.
      def fullname
        File.join(@location, @filename)
      end

      # Extracts hashes from a build identity property list.
      #
      # @param path [String] The path to the build identity plist.
      # @return [Array<MooTool::Models::Digest>] The list of digests found.
      def hashes_from_build_identity(path)
        parsed = CFPropertyList.native_types(CFPropertyList::List.new(file: path).value).deep_symbolize_keys

        results = parsed[:BuildIdentities].flat_map do |identity|
          identity[:Manifest].map do |_key, value|
            value[:Digest]
          end
        end

        results.uniq.map { |h| Models::Digest.create(h) }
      end

      # Lazily calculates and returns the hashes for the file.
      #
      # @return [Array<MooTool::Models::Digest>] The list of hashes.
      def hashes
        @hashes = begin
          IMG4::File.load("#{@location}/#{filename}").hashes
        rescue StandardError
          [MooTool::Models::Digest.create(::Digest::SHA384.digest(@filename)),
           MooTool::Models::Digest.create(::Digest::SHA256.digest(@filename))]
        end
      end

      # Converts the file location to a hash representation.
      #
      # @return [Hash] A hash containing path, location, filename, and hashes.
      def to_h
        { path: fullname, location: @location, filename: @filename, hashes: @hashes }
      end

      # Returns the full path as a string.
      #
      # @return [String] The full path.
      def to_s
        fullname
      end

      # Checks if the file is likely an IMG4 related file based on its extension or name.
      #
      # @return [Boolean] True if it's an IMG4 file, false otherwise.
      def img4?
        case fullname
        when /\.img4$/, /\.im4m$/, /\.im4p$/, /apticket.*\.der/, /com\.apple\.factorydata/
          true
        else
          false
        end
      end

      # Checks if the file matches the given hash.
      #
      # @param hash [String, MooTool::Models::Digest] The hash to check.
      # @return [Boolean] True if a match is found, false otherwise.
      def hash?(hash)
        hash = MooTool::Models::Digest.create(hash) unless hash.is_a?(MooTool::Models::Digest)
        @hashes.any? { |h| h == hash }
      end

      # Converts the file location to a JSON-compatible hash.
      #
      # @param _options [Hash] Serialization options.
      # @return [Hash] The serialized representation.
      def as_json(_options = {})
        to_h
      end

      # Serializes the file location to a JSON string.
      #
      # @param options [Array] Serialization options.
      # @return [String] The JSON string.
      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      # Returns a reference string for the file.
      #
      # @param _hash [String] Unused parameter.
      # @return [String] The full path.
      def to_ref(_hash)
        fullname.to_s
      end

      # Returns a string representation of the object for debugging.
      #
      # @return [String] The inspected hash.
      def inspect
        to_h.ai
      end

      # Creates a new FileLocation instance from a hash.
      #
      # @param hash [Hash] A hash containing 'location', 'filename', and optionally 'hashes'.
      # @return [FileLocation] A new instance.
      def self.from_hash(hash)
        if hash.key? 'hashes'
          new hash['location'], hash['filename'], hash['hashes']
        else
          new hash['location'], hash['filename']
        end
      end
    end
  end
end
