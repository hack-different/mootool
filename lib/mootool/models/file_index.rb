# frozen_string_literal: true

module MooTool
  module Models
    class FileIndex
      PATHS = %w[
        /System/Volumes/Hardware/FactoryData/System/Library/Caches/com.apple.factorydata
      ].freeze

      MOUNTS_PATTERNS = %w[
        iSCPreboot
        Preboot
        Update
        Recovery
        Hardware
      ].freeze

      FILE_KINDS = %w[
        kernelcache* kernel sep-patches* imutablekernel *.der *.im4m *.aea.* ft*.bin
        *.im4p *.dmg *.der *.img4 *.pem *request.txt *response.txt dmg.*
      ].freeze

      def initialize(index = nil)
        @index = index || []
      end

      attr_reader :index

      def self.current
        @current ||= load('/Users/rickmark/Desktop/index.json')
      end

      def self.load(path)
        json_data = JSON.parse(File.read(path))

        index_data = json_data.map do |entry|
          FileLocation.from_hash entry
        end

        @index = new(index_data)
      rescue StandardError
        new([])
      end

      def mounts
        MOUNTS_PATTERNS.flat_map do |pattern|
          volume_mounts = Dir.glob("/Volumes/#{pattern}*")
          volume_mounts + ["/System/Volumes/#{pattern}"]
        end
      end

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

      def as_json(options = {})
        @index.map { |e| e.as_json(options) }
      end

      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      def has_hash?(hash)
        @index.any? do |entry|
          entry.hash? hash
        end
      end

      def files_with_hash(hash)
        @index.select { |entry| entry.hash? hash }
      end

      def generate_hashes
        @index.each(&:generate_hashes)
      end
    end
  end
end
