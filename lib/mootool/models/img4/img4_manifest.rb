# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents an IMG4 Manifest (IM4M), typically used for APTickets or data validation.
      class IMG4Manifest
        include MooTool::Helpers::IMG4
        include Helpers::Hashing

        # @return [Array<OpenSSL::X509::Certificate>, nil] The certificate chain included in the manifest.
        attr_reader :certificates

        # @return [String, nil] The cryptographic signature of the manifest body.
        attr_reader :signature

        # Initializes a new IMG4Manifest from ASN.1 data.
        #
        # @param input [OpenSSL::ASN1::ASN1Data] The raw ASN.1 structure.
        def initialize(input)
          @input = input

          @data = if @input.value.size == 1
                    input.value[0]
                  else
                    input
                  end

          @version = @data.value[1].value.to_i
          @body = construct(@data.value[2])
          @body = @body.first if @body.is_a? Array
          @signature = File.parse_signature(@data.value[3]) if @data.value[3]
          @certificates = File.parse_certificates(@data.value[4]) if @data.value[4]
        end

        # Converts the manifest to a hash representation.
        #
        # @return [Hash] A hash containing the manifest components.
        def to_h
          {
            version: @version,
            body: @body,
            signature: @signature,
            certificates: @certificates
          }.compact
        end

        # Provides a human-readable inspection of the manifest.
        #
        # @return [String] The awesome_print representation.
        def inspect
          to_h.ai
        end

        # Returns the DER-encoded bytes of the manifest.
        #
        # @return [String] The DER bytes.
        def to_bytes
          @data.to_der
        end

        # Converts the manifest into a tree structure for visualization.
        #
        # @return [Helpers::TreeNode] The root node of the tree.
        def to_tree
          node = Helpers::TreeNode.new(Models::IMG4.key_name(:IM4M).ai)

          node.children << Helpers::TreeNode.new("Version: #{@version.ai}")
          node.children << @body.to_tree if @body
          node.children << Helpers::TreeNode.new('Signature', [Helpers::TreeNode.new(@signature.ai)]) if @signature
          node.children << Helpers::TreeNode.new('Certificates', @certificates.map(&:to_tree)) if @certificates

          node
        end

        # Validates the certificate chain against known root certificates.
        #
        # @return [Array<Hash>] An array of validation results for each certificate in the chain.
        def validate
          @certificates ||= []
          @certificates.map do |certificate|
            validator_certs = CertificateIndex.current.index.sort_by do |_hash, validator_certificate|
              validator_certificate.subject.to_s
            end

            validator_certs = validator_certs.uniq { |_hash, cert| cert.digest }
            validations = validator_certs.map do |_hash, validator_certificate|
              {
                subject: validator_certificate.subject.to_s,
                issuer: validator_certificate.issuer.to_s,
                fingerprint: validator_certificate.fingerprint,
                digest: validator_certificate.digest,
                valid: certificate.verify(validator_certificate.public_key)
              }
            end
            valid_certs = validations.select do |validation|
              validation[:valid] || validation[:subject] == certificate.issuer.to_s
            end

            {
              subject: certificate.subject.to_s,
              issuer: certificate.issuer.to_s,
              fingerprint: certificate.fingerprint,
              key_id: certificate.key_id,
              validations: valid_certs.uniq { |cert| cert[:digest].shasum }
            }.compact
          end
        end

        # Returns the DER-encoded signed data (the MANB sequence).
        #
        # @return [String] The raw DER bytes of the body.
        def signed_data
          @data.value[2].to_der
        end

        # Provides raw hashes for the manifest and its signed data.
        #
        # @return [Array<Hash>] An array of hash entries.
        def raw_hashes
          [
            { kind: :manifest_hash, value: to_bytes },
            { kind: :signed_data, value: signed_data }
          ]
        end

        # Retrieves a specific firmware entry from the manifest body.
        #
        # @param type [Symbol, String] The tag of the firmware entry.
        # @return [FirmwareEntry, nil] The firmware entry if found.
        def firmware_tag(type)
          @body.to_h[:MANB][type.to_sym]
        end

        # Extracts all public keys from the certificate chain.
        #
        # @return [Hash{String => OpenSSL::PKey::PKey}] A map of subjects to public keys.
        def public_keys
          @certificates.to_h do |certificate|
            [certificate.subject.to_s, certificate.public_key]
          end
        end
      end
    end
  end
end
