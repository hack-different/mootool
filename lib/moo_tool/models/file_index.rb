require 'digest'
require 'colorize'
module MooTool
  module Models
    class FileIndex
      class FileLocation
        attr_accessor :location, :filename, :hashes

        def initialize(location, filename, hashes = nil)
          @location = location
          @filename = filename
          case hashes
          when Models::Digest
            @hashes = [hashes]
          when String
            [Models::Digest.create(hashes)]
          when Array
            @hashes = hashes.map {|h| Models::Digest.create(h)}
          end

        end

        def fullname
          File.join(@location, @filename)
        end

        def generate_hashes
          @hashes = case @filename
          when /.*\.img4/
            IMG4::File.load("#{@location}/#{filename}").hashes
          when /.*\.im4p/
            IMG4::File.load("#{@location}/#{filename}").hashes
            when /.*\/kernelcache(.*)/
            IMG4::File.load("#{@location}/#{filename}").hashes
            else
          [Models::Digest.create(::Digest::SHA384.digest(@filename))]
                    end
        end

        def to_h
          { path: self.fullname, location: @location, filename: @filename, hashes: @hashes }
        end

        def hash?(hash)
          hash = Models::Digest.create(hash) unless hash.is_a?(Models::Digest)
          @hashes.any? {|h| h == hash }
        end

        def as_json(options = {})
          to_h
        end

        def to_json(*options)
          as_json(*options).to_json(*options)
        end

        def to_ref(hash)
          "#{self.fullname}"
        end

        def inspect
          to_h.ai
        end

        def self.from_hash(hash)
          if hash.key? 'hashes'
            new hash['location'], hash['filename'], hash['hashes']
          else
            new hash['location'], hash['filename']
          end

        end
      end

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
        kernelcache* kernel sep-patches* imutablekernel *.der *.im4m root_hash
        *.im4p *.dmg *.der *.img4 *.pem *request.txt *response.txt dmg.*
      ].freeze

      def initialize(index = nil)
        @index = index
        unless @index
        perform
        end
      end

      attr_reader :index

      def self.load(path)
        json_data = JSON.parse(File.read(path))

        index_data = json_data.map do |entry|
          FileLocation.from_hash entry
        end

        new index_data
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
            FileLocation.new(path, file)
          end
        end

        search_names = mounts.flat_map do |path|
          Dir.glob("**/{#{FILE_KINDS.join(',')}}", base: path).map do |file|
            FileLocation.new(path, file)
          end
        end

        @index = flat_names + search_names
        @index.reject! { |e| File.directory? e.fullname }
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

      def hash
        @index.each do |entry|
          entry.generate_hashes
        end
      end
    end
  end
end
