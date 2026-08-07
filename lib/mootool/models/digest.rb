# frozen_string_literal: true

module MooTool
  module Models
    # A wrapper around binary data, typically used for digests, signatures, or identifiers
    #
    # Despite the name, this class is a generic holder for binary data with utility
    # methods for hex conversion, comparison, and integration with other MooTool models.
    class Digest
      # @return [String] The raw binary value.
      attr_reader :value
      # @return [String, nil] A hint about the data type or hash algorithm.
      attr_accessor :hint

      # Initializes a new Digest object
      #
      # @param value [String, Integer] The binary data or an integer to be converted to binary.
      # @param hint [String, nil] Optional hint about the data.
      # @raise [ArgumentError] If the input cannot be parsed as binary data.
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

      # Checks if the digest was initialized from an integer
      #
      # @return [Boolean]
      def integer?
        @integer
      end

      # Returns files in the current index that match this digest's hash
      #
      # @return [Array<Models::FileLocation>]
      def files
        @files ||= FileIndex.current.files_with_hash(shasum)
      end

      # Parses a hex string into a Digest object
      #
      # @param value [String] The hex string.
      # @return [Digest]
      def self.parse(value)
        new [value].pack('H*')
      end

      # Computes a SHA-384 hash of the input and returns a Digest object
      #
      # @param value [String] The data to hash.
      # @return [Digest]
      def self.digest(value)
        hash = ::Digest::SHA384.digest value
        new hash, 'SHA384'
      end

      # Creates a Digest object from a hex string
      #
      # @param value [String] The hex string.
      # @return [Digest]
      def self.from_hex(value)
        new [value].pack('H*')
      end

      # Factory method to create Digest objects or other types based on input
      #
      # @param input [String, Array, Digest, nil] The input data.
      # @param hint [String, nil] Optional hint.
      # @return [Digest, UUIDTools::UUID, Array, nil]
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

      # Returns the raw binary value
      #
      # @return [String]
      def to_s
        value
      end

      # Returns the hex representation of the digest
      #
      # @return [String]
      def shasum
        hex
      end

      # Returns the hex representation of the digest in uppercase
      #
      # @return [String]
      def hex
        to_s.unpack1('H*').upcase
      end

      # Returns properties from manifests that match this digest's hash
      #
      # @return [Array]
      def properties
        Digest.manifests.properties_with_hash(shasum)
      end

      # Returns the shared IOReg manifest index
      #
      # @return [Models::IOReg]
      def self.manifests
        @manifests ||= MooTool::Models::IOReg.create
      end

      # Loads manifests from a specified path
      #
      # @param path [String] The path to the manifest file.
      # @return [Models::IOReg]
      def self.load_manifests(path)
        @manifest = MooTool::Models::IOReg.create path
      end

      # Returns the hex representation for JSON serialization
      #
      # @return [String]
      def as_json(*_options)
        shasum
      end

      # Returns the size of the binary data in bytes
      #
      # @return [Integer]
      def size
        value.size
      end

      # Compares this digest with another object
      #
      # @param other [Digest, String, Object] The object to compare with.
      # @return [Boolean] True if the values match.
      def ==(other)
        if other.is_a?(MooTool::Models::Digest)
          value == other.value
        elsif other.is_a?(String)
          hex == other.unpack1('H*').upcase || hex == other
        else
          value == other
        end
      end

      # Converts the digest to JSON
      #
      # @return [String]
      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      # Returns the hex representation for inspection
      #
      # @return [String]
      def inspect
        to_s.unpack1('H*').upcase
      end
    end
  end
end
