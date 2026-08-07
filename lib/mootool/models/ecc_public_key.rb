# frozen_string_literal: true

module MooTool
  module Models
    # Represents an Elliptic Curve Cryptography (ECC) public key.
    class ECCPublicKey
      include MooTool::Helpers::IMG4

      # @return [OpenSSL::ASN1::ASN1Data, OpenSSL::PKey::EC::Point] The raw value of the public key.
      # @return [OpenSSL::PKey::EC::Group] The elliptic curve group associated with the key.
      # @return [OpenSSL::PKey::EC::Point] The elliptic curve point representing the public key.
      attr_reader :value, :curve, :point

      # Initializes a new ECCPublicKey instance.
      #
      # @param key [OpenSSL::PKey::EC::Point, String] The public key as a point or encoded ASN1 string.
      def initialize(key)
        if key.is_a?(OpenSSL::PKey::EC::Point)
          @value = key
          @curve = @value.group
          @point = @value
        else
          @value = OpenSSL::ASN1.decode(key)

          @curve = OpenSSL::PKey::EC::Group.new @value.value[0].value[1].value
          @point = OpenSSL::PKey::EC::Point.new @curve, @value.value[1].value
        end
      end

      # Creates a point from raw data by attempting multiple curves.
      #
      # @param point [String] The raw point data.
      # @return [OpenSSL::PKey::EC::Point, nil] The parsed point or nil if parsing failed.
      def self.from_point(point)
        parse_point_any(point)
      end

      # Attempts to create an ECC public key point from X and Y coordinates.
      #
      # @param x [Object] The X coordinate (expects a value attribute).
      # @param y [Object] The Y coordinate (expects a value attribute).
      # @return [OpenSSL::PKey::EC::Point, Array] The parsed point or an array of [x, y] if parsing failed.
      def self.try_from_x_y(x, y)
        combined_point = "\u0004#{x.value}#{y.value}"
        result = parse_point_any(combined_point)
        result || [x, y]
      end

      # Parses an ECC point by trying known elliptic curve groups.
      #
      # @param point [String] The raw point data to parse.
      # @return [OpenSSL::PKey::EC::Point, nil] The first successfully parsed point, or nil.
      def self.parse_point_any(point)
        %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end.compact.first
      end

      def inspect
        to_h.ai
      end

      # Compares this ECC public key with another key or point.
      #
      # @param other [MooTool::Models::ECCPublicKey, OpenSSL::PKey::EC] The object to compare with.
      # @return [Boolean] True if the keys are equal, false otherwise.
      def ==(other)
        case other
        when MooTool::Models::ECCPublicKey
          @curve == other.curve && @point == other.point
        when OpenSSL::PKey::EC
          @curve == other.group && @point = other.public_key
        end
      end
    end
  end
end
