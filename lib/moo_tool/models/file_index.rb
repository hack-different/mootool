# frozen_string_literal: true

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
            @hashes = hashes.map { |h| Models::Digest.create(h) }
          end
        end

        def fullname
          File.join(@location, @filename)
        end


        def hashes_from_build_identity(path)
          parsed = CFPropertyList.native_types(CFPropertyList::List.new(file: path).value).deep_symbolize_keys

          results = parsed[:BuildIdentities].flat_map do |identity|
            identity[:Manifest].map do |_key, value|
              value[:Digest]
            end
          end

          results.uniq.map { |h| Models::Digest.create(h) }
        end

        def generate_hashes

          @hashes = begin
            IMG4::File.load("#{@location}/#{filename}").hashes
          rescue StandardError
            [Models::Digest.create(::Digest::SHA384.digest(@filename)), Models::Digest.create(::Digest::SHA256.digest(@filename))]
          end
        end

        def to_h
          { path: fullname, location: @location, filename: @filename, hashes: @hashes }
        end

        def hash?(hash)
          hash = Models::Digest.create(hash) unless hash.is_a?(Models::Digest)
          @hashes.any? { |h| h == hash }
        end

        def as_json(_options = {})
          to_h
        end

        def to_json(*options)
          as_json(*options).to_json(*options)
        end

        def to_ref(_hash)
          fullname.to_s
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
        kernelcache* kernel sep-patches* imutablekernel *.der *.im4m *.aea.* ft*.bin
        *.im4p *.dmg *.der *.img4 *.pem *request.txt *response.txt dmg.*
      ].freeze

      def initialize(index = nil)
        @index = index
        return if @index

        perform
      end

      attr_reader :index

      def self.load(path)
        json_data = JSON.parse(File.read(path))

        index_data = json_data.map do |entry|
          FileLocation.from_hash entry
        end

        new index_data
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
            FileLocation.new(path, file)
          end
        end

        search_names = mounts.flat_map do |path|
          Dir.glob("**/{#{FILE_KINDS.join(',')}}", base: path).map do |file|
            FileLocation.new(path, file)
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

      def hash
        @index.each(&:generate_hashes)
      end
    end
  end
end
