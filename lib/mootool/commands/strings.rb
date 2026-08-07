# frozen_string_literal: true

module MooTool
  module Commands
    # CLI commands for extracting and indexing strings from file payloads.
    class Strings < Thor
      desc 'index', 'Indexes certificates throughout the land'
      # Indexes and extracts strings from IMG4 payloads found in system files.
      #
      # Extracted strings are saved to a temporary directory, partitioned by the file's hash.
      #
      # @return [void]
      # @example Index and extract strings
      #   mootool strings index
      def index
        indexer = Models::FileIndex.new
        indexer.perform

        indexer.index.select(&:img4?).flat_map do |file_location|
          loaded = Models::IMG4::File.load(file_location)
          loaded.payload.extract_to File.join(MooTool.temp_directory('strings'), loaded.file_hash) if loaded.payload?
        end
      end
    end
  end
end
