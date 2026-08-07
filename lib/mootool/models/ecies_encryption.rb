# frozen_string_literal: true

module MooTool
  module Models
    # Represents Elliptic Curve Integrated Encryption Scheme (ECIES) Encryption data.
    class ECIESEncryption
      include MooTool::Helpers::IMG4

      # @return [OpenSSL::PKey::EC::Point] The elliptic curve point.
      # @return [MooTool::Models::Digest] The nonce used for encryption.
      attr_reader :point, :nonce

      # Initializes a new ECIESEncryption instance.
      #
      # @param input [OpenSSL::PKey::EC::Point] The ECC point.
      # @param nonce [String, MooTool::Models::Digest] The nonce data.
      def initialize(input, nonce)
        # Recall that uncompressed points start with 0x04 to indicate that they are uncompressed
        # To get the proper X / Y we must trip this off first, then divide the string in half
        hex = input.to_octet_string(:uncompressed)[1..]
        pair = hex[0..(hex.length / 2)], hex[(hex.length / 2)..]
        @point = input
        @e_x = Models::Digest.create pair[0]
        @e_y = Models::Digest.create pair[1]

        @nonce = Models::Digest.create(nonce)
      end

      # Decodes ECIES data from DER format.
      #
      # @param data [String] The DER encoded data.
      # @return [OpenSSL::ASN1::ASN1Data] The decoded ASN1 data.
      def self.from_der(data)
        OpenSSL::ASN1.decode(data)
      end

      # Parses an ECC point by trying known elliptic curve groups.
      #
      # @param point [String] The raw point data to parse.
      # @return [OpenSSL::PKey::EC::Point, nil] The first successfully parsed point, or nil.
      def parse_point_any(point)
        mappings = %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end

        mappings.compact.first
      end

      # Returns the curve name of the elliptic curve group.
      #
      # @return [String] The curve name (e.g., 'prime256v1').
      def group
        @point.group.curve_name
      end

      # Converts the ECIES encryption data to a hash.
      #
      # @return [Hash] A hash containing SHASUMs of E_X, E_Y, and the nonce.
      def to_h
        { e_x: @e_x.shasum, e_y: @e_y.shasum, n: @nonce.shasum }
      end

      # Returns a string representation of the object for debugging.
      #
      # @return [String] The inspected hash.
      def inspect
        to_h.ai
      end
    end
  end
end
