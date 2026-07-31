# frozen_string_literal: true

module MooTool
  module Models
    # Digest is a misnomer, this is a generic holder of binary data
    class Digest
      attr_reader :value
      attr_accessor :hint

      def initialize(value, hint = nil)
        @hint = hint

        case value
        when String
          @value = value
          @hint = 'SHA1' if value.length == 20
          @hint = 'SHA256' if value.length == 32
          @hint = 'SHA384' if value.length == 48
        when Integer
          @value = [value.to_s(16)].pack('H*')
          @hint = hint
          @integer = true
        else
          raise ArgumentError, "Invalid Input: #{value.inspect}"
        end
      rescue StandardError
        raise "Value #{value} with class #{value.class} could not be parsed"
      end

      def integer?
        @integer
      end

      def files
        @files ||= FileIndex.current.files_with_hash(shasum)
      end

      def self.parse(value)
        new [value].pack('H*')
      end

      def self.digest(value)
        hash = ::Digest::SHA384.digest value
        new hash, 'SHA384'
      end

      def self.from_hex(value)
        new [value].pack('H*')
      end

      def self.create(input, hint = nil)
        if input.is_a?(String) && input.length == 16 && hint.nil?
          UUIDTools::UUID.parse_raw input
        elsif input.is_a?(Array)
          input.map { |i| create(i, hint) }
        elsif input.nil?
          nil
        elsif input.is_a?(Digest)
          input
        else
          Digest.new input, hint
        end
      end

      def to_s
        value
      end

      def shasum
        hex
      end

      def hex
        to_s.unpack1('H*').upcase
      end

      def properties
        Digest.manifests.properties_with_hash(shasum)
      end

      def self.manifests
        @manifests ||= MooTool::Models::IOReg.create
      end

      def self.load_manifests(path)
        @manifest = MooTool::Models::IOReg.create path
      end

      def as_json(*_options)
        shasum
      end

      def size
        value.size
      end

      def ==(other)
        if other.is_a?(MooTool::Models::Digest)
          value == other.value
        elsif other.is_a?(String)
          hex == other.unpack1('H*').upcase || hex == other
        else
          value == other
        end
      end

      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      def inspect
        to_s.unpack1('H*').upcase
      end
    end
  end
end
