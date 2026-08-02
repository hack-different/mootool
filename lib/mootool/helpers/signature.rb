# frozen_string_literal: true

module MooTool
  module Helpers
    # Helper methods for performing validation of signature vs certificates
    module Signature
      extend ActiveSupport::Concern

      def validate_signature
        leaf_certificate = validted_certificate_chain
        digest = OpenSSL::Digest.new('SHA384')
        values = %i[IM4M IM4P].map do |kind|
          OpenSSL::Digest::SHA384.digest(@content[kind]&.to_bytes)
        end.compact

        signatures = %i[IM4P IM4M].map do |kind|
          signature = @content[kind]&.signature
          signature.respond_to?(:value) ? signature.value : signature
        end.compact

        signatures.flat_map do |signature|
          values.map do |value|
            { digest.hexdigest(value) => leaf_certificate.public_key.verify(digest, signature, value) }
          end
        end.reduce(&:merge)
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
