# frozen_string_literal: true

module MooTool
  module Models
    # Represents an ECC public key
    class ECCPublicKey
      include MooTool::Helpers::IMG4

      attr_reader :value, :curve, :point

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

      def self.from_point(point)
        parse_point_any(point)
      end

      def self.parse_point_any(point)
        %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end.compact.first
      end

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
