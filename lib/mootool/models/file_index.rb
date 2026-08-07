# frozen_string_literal: true

module MooTool
  module Models
    # Represents a collection of file locations and their associated hashes.
    class FileIndex
      include Helpers::File

      # Default paths to search for files.
      PATHS = %w[
        /System/Volumes/Hardware/FactoryData/System/Library/Caches/com.apple.factorydata
      ].freeze

      # Volume mount patterns to search.
      MOUNTS_PATTERNS = %w[
        iSCPreboot
        Preboot
        Update
        Recovery
        Hardware
      ].freeze

      # Glob patterns for file kinds to include in the index.
      FILE_KINDS = %w[
        kernelcache* kernel sep-patches* imutablekernel *.der *.im4m *.aea.* ft*.bin
        *.im4p *.dmg *.der *.img4 *.pem *request.txt *response.txt dmg.*
      ].freeze

      # Initializes a new FileIndex instance.
      #
      # @param index [Array, String, nil] An existing index as an array of FileLocation or a JSON string.
      # @param path [String, nil] The path associated with the index.
      def initialize(index = nil, path = nil)
        @path = path
        if index.is_a?(Array)
          @index = index
        else
          json_data = JSON.parse(index)

          @index = json_data.map do |entry|
            FileLocation.from_hash entry
          end
        end
      rescue StandardError
        @index = []
      end

      # @return [Array<FileLocation>] The list of indexed file locations.
      attr_reader :index

      # Returns the current singleton instance of FileIndex, loading it from a default path if necessary.
      #
      # @return [FileIndex] The current file index instance.
      def self.current
        @current ||= load('/Users/rickmark/Desktop/index.json')
      end

      # Discovers relevant mount points based on {MOUNTS_PATTERNS}.
      #
      # @return [Array<String>] A list of volume mount paths.
      def mounts
        MOUNTS_PATTERNS.flat_map do |pattern|
          volume_mounts = Dir.glob("/Volumes/#{pattern}*")
          volume_mounts + ["/System/Volumes/#{pattern}"]
        end
      end

      # Performs the file indexing by searching {PATHS} and discovered {mounts}.
      #
      # @return [Array<FileLocation>] The resulting index.
      def perform
        flat_names = PATHS.flat_map do |path|
          Dir.glob('**/*', base: path).map do |file|
            MooTool::Models::FileLocation.new(path, file)
          end
        end

        search_names = mounts.flat_map do |path|
          Dir.glob("**/{#{FILE_KINDS.join(',')}}", base: path).map do |file|
            MooTool::Models::FileLocation.new(path, file)
          rescue StandardError
            next
          end
        end

        @index = flat_names + search_names
        @index.reject! do |e|
          File.directory? e.fullname
        rescue Errno::EACCES, Errno::EPERM
          true
        end
      end

      # Converts the index to a JSON-compatible array.
      #
      # @param options [Hash] Serialization options.
      # @return [Array<Hash>] The serialized index.
      def as_json(options = {})
        @index.map { |e| e.as_json(options) }
      end

      # Serializes the index to a JSON string.
      #
      # @param options [Array] Serialization options.
      # @return [String] The JSON string.
      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      # Checks if any file in the index matches the given hash.
      #
      # @param hash [String] The hash to search for.
      # @return [Boolean] True if a match is found, false otherwise.
      def hash?(hash)
        @index.any? do |entry|
          entry.hash? hash
        end
      end

      # Finds all files in the index that match the given hash.
      #
      # @param hash [String] The hash to search for.
      # @return [Array<FileLocation>] The list of matching file locations.
      def files_with_hash(hash)
        @index.select { |entry| entry.hash? hash }
      end

      # Generates hashes for all files currently in the index.
      #
      # @return [Array<FileLocation>] The index after hash generation.
      def generate_hashes
        @index.each(&:hashes)
      end
    end
  end
end
