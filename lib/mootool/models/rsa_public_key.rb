# frozen_string_literal: true

module MooTool
  module Models
    # Represents an RSA public key
    class RSAPublicKey
      include MooTool::Helpers::IMG4

      attr_reader :n, :e, :value

      def initialize(key)
        return unless key.is_a?(OpenSSL::PKey::RSA)

        @value = key
        @n = @value.n
        @e = @value.e
      end

      def n_hex
        Models::Digest.new(@n.to_i).shasum
      end

      def ==(other)
        case other
        when OpenSSL::PKey::RSA, MooTool::Models::RSAPublicKey
          @n == other.n && @e == other.e
        else
          false
        end
      end
    end
  end
end
