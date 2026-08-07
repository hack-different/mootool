# frozen_string_literal: true

module MooTool
  module Models
    # Represents an Elliptic Curve Cryptography (ECC) Signature.
    class ECCSignature
      include MooTool::Helpers::IMG4

      # @return [String] The raw signature value.
      attr_reader :value

      # Initializes a new ECCSignature instance.
      #
      # @param signature [String] The raw signature data to decode.
      def initialize(signature)
        @value = signature
        @values = construct(OpenSSL::ASN1.decode(signature))
        @r, @s = @values
      end

      # Converts the signature to a hash containing the r and s components.
      #
      # @return [Hash] A hash with keys :r and :s.
      def to_h
        { r: @r, s: @s }
      end

      # Factory method to create a signature object based on the input size.
      #
      # @param signature [String, MooTool::Models::Digest] The signature data or digest object.
      # @return [MooTool::Models::ECCSignature, Object] The created signature object or the original input.
      def self.create(signature)
        size = signature.is_a?(MooTool::Models::Digest) ? signature.value.size : signature.size
        if size > 128
          # RSA Signature
          signature.hint = 'RSASignature' if signature.respond_to?(:hint)
          signature
        else
          value = signature.respond_to?(:value) ? signature.value : signature
          MooTool::Models::ECCSignature.new(value)
        end
      end
    end
  end
end
