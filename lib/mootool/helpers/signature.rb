# frozen_string_literal: true

module MooTool
  module Helpers
    # Helper methods for performing validation of digital signatures against certificates
    #
    # This module provides functionality to verify signatures using public keys extracted
    # from certificates and comparing them against signed data.
    module Signature
      extend ActiveSupport::Concern

      # Checks if the object has at least one valid signature
      #
      # @return [Boolean] True if at least one signature is valid, or if no signatures exist.
      def valid_signature?
        signatures = validate_signature
        if signatures
          signatures.any? { |entry| entry[:valid] == true }
        else
          true
        end
      end

      # Checks if any signatures are present
      #
      # @return [Boolean] True if signatures are present.
      def signature?
        validate_signature.present?
      end

      # Validates all signatures against all available public keys
      #
      # @return [Array<Hash>] A list of validation results, each containing:
      #   * :signature_kind [Symbol] The type of signature.
      #   * :fingerprint [String] The fingerprint of the public key used.
      #   * :hash_kind [Symbol] The type of hash verified.
      #   * :hash [Models::Digest] The hash of the signed data.
      #   * :valid [Boolean] Whether the signature is valid.
      def validate_signature
        signatures.flat_map do |signature_pair|
          signature_kind = signature_pair[:kind]
          signature = signature_pair[:value]
          signature = signature.value if signature.is_a?(Models::ECCSignature)
          public_keys.flat_map do |subject, public_key|
            hash_pairing = raw_hashes.find { |h| h[:kind] == :signed_data }
            hash_kind = hash_pairing[:kind]
            raw_hash = hash_pairing[:value]
            printable_hash = Models::Digest.new(::Digest::SHA384.digest(raw_hash))

            raw_hash = raw_hash.value if raw_hash.is_a?(Models::Digest)
            signature = signature.value if signature.is_a?(Models::Digest)
            result = public_key.verify('SHA384', signature, raw_hash)
            MooTool::Models::PayloadSignature.new(
              signature_kind: signature_kind,
              subject: subject,
              hash_kind: hash_kind,
              hash: printable_hash,
              valid: result
            )
          end
        end
      end

      class_methods do
        # Parses a raw signature into an appropriate model (RSA or ECC)
        #
        # @param signature [OpenSSL::ASN1::OctetString, String] The raw signature data.
        # @return [Models::Digest, Models::ECCSignature] The parsed signature model.
        def parse_signature(signature)
          signature = signature.value if signature.is_a?(OpenSSL::ASN1::OctetString)
          if signature.size > 128
            Models::Digest.create(signature, 'RSASignature')
          else
            ::MooTool::Models::ECCSignature.create(signature)
          end
        end

        # Parses a list of raw certificates into Certificate objects
        #
        # @param certificates [Array<Models::Digest, OpenSSL::X509::Certificate, String>]
        #   List of raw certificates or certificate-like objects.
        # @return [Array<Models::Certificate>] List of parsed Certificate objects.
        def parse_certificates(certificates)
          certificates.map do |certificate|
            certificate_data = certificate.value if certificate.is_a?(Models::Digest)
            certificate_data = certificate.to_der if certificate.respond_to?(:to_der)
            Models::Certificate.new OpenSSL::X509::Certificate.new(certificate_data)
          end
        end
      end
    end
  end
end
