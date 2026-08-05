# frozen_string_literal: true

module MooTool
  module Commands
    # Commands for interacting with payloads and extracting strings
    class Strings < Thor
      desc 'index', 'Indexes certificates throughout the land'
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
