# frozen_string_literal: true

module MooTool
  module Models
    class FileLocation
      attr_accessor :location, :filename, :hashes

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

      def has_hash?
        @hashes&.any?
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
          [MooTool::Models::Digest.create(::Digest::SHA384.digest(@filename)),
           MooTool::Models::Digest.create(::Digest::SHA256.digest(@filename))]
        end
      end

      def to_h
        { path: fullname, location: @location, filename: @filename, hashes: @hashes }
      end

      def hash?(hash)
        hash = MooTool::Models::Digest.create(hash) unless hash.is_a?(MooTool::Models::Digest)
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
  end
end
