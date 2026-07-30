# frozen_string_literal: true

module MooTool
  module Models
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
