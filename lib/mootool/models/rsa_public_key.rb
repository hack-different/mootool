# frozen_string_literal: true

module MooTool
  module Models
    # Represents an RSA public key.
    class RSAPublicKey
      include MooTool::Helpers::IMG4

      # @return [OpenSSL::BN] The modulus of the RSA public key.
      # @return [OpenSSL::BN] The public exponent of the RSA public key.
      # @return [OpenSSL::PKey::RSA] The raw RSA public key object.
      attr_reader :n, :e, :value

      # Initializes a new RSAPublicKey instance.
      #
      # @param key [OpenSSL::PKey::RSA] The RSA public key.
      def initialize(key)
        return unless key.is_a?(OpenSSL::PKey::RSA)

        @value = key
        @n = @value.n
        @e = @value.e
      end

      # Returns the hex representation of the modulus (n).
      #
      # @return [String] The SHASUM of the modulus.
      def n_hex
        Models::Digest.new(@n.to_i).shasum
      end

      def to_h
        {
          n: @n.to_s(16),
          e: @e
        }
      end

      # Compares this RSA public key with another RSA key.
      #
      # @param other [OpenSSL::PKey::RSA, MooTool::Models::RSAPublicKey] The other key to compare with.
      # @return [Boolean] True if the modulus and exponent are equal, false otherwise.
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
