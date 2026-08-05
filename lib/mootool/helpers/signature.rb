# frozen_string_literal: true

module MooTool
  module Helpers
    # Helper methods for performing validation of signature vs certificates
    module Signature
      extend ActiveSupport::Concern

      def valid_signature?
        signatures = validate_signature
        if signatures
          signatures.any? { |_key, entry| entry[:valid] == true }
        else
          true
        end
      end

      def signature?
        validate_signature.present?
      end

      def validate_signature
        signatures.flat_map do |signature_pair|
          signature_kind = signature_pair[:kind]
          signature = signature_pair[:value]
          signature = signature.value if signature.is_a?(Models::ECCSignature)
          public_keys.flat_map do |fingerprint, public_key|
            hash_pairing = raw_hashes.find { |h| h[:kind] == :signed_data }
            hash_kind = hash_pairing[:kind]
            raw_hash = hash_pairing[:value]
            printable_hash = Models::Digest.new(::Digest::SHA384.digest(raw_hash))

            raw_hash = raw_hash.value if raw_hash.is_a?(Models::Digest)
            signature = signature.value if signature.is_a?(Models::Digest)
            result = public_key.verify('SHA384', signature, raw_hash)
            {
              signature_kind: signature_kind,
              fingerprint: fingerprint,
              hash_kind: hash_kind,
              hash: printable_hash,
              valid: result
            }
          end
        end
      end

      class_methods do
        def parse_signature(signature)
          signature = signature.value if signature.is_a?(OpenSSL::ASN1::OctetString)
          if signature.size > 128
            Models::Digest.create(signature, 'RSASignature')
          else
            ::MooTool::Models::ECCSignature.create(signature)
          end
        end

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
