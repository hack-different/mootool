# frozen_string_literal: true

require 'openssl'

module OpenSSL
  module ASN1
    class ASN1Data
      # Returns true if this ASN1 object uses a PRIVATE tag class.
      #
      # @return [Boolean]
      def private_tag?
        tag_class == :PRIVATE
      end

      # Returns true if this ASN1 object uses a CONTEXT_SPECIFIC tag class.
      #
      # @return [Boolean]
      def context_specific?
        tag_class == :CONTEXT_SPECIFIC
      end

      # Returns true if this ASN1 object uses a UNIVERSAL tag class.
      #
      # @return [Boolean]
      def universal?
        tag_class == :UNIVERSAL
      end

      # Returns true if this ASN1 object is a Constructive (Sequence, Set, or tagged constructed).
      #
      # @return [Boolean]
      def constructive?
        is_a?(OpenSSL::ASN1::Constructive)
      end

      # Returns the tag value as a 4CC symbol when applicable (PRIVATE tags).
      #
      # @return [Symbol, Integer] The 4CC symbol or raw tag integer.
      def tag_label
        if private_tag? && tag.respond_to?(:to_4cc)
          tag.to_4cc
        else
          tag
        end
      end
    end
  end
end
