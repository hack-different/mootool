# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # IMG4 Manifests are used in multiple ways, such as an APTicket which is a combined set of acceptable hashes,
      # or as additional properties included in data such as FDR.
      class IMG4Manifest
        include MooTool::Helpers::IMG4
        include Helpers::Hashing

        attr_reader :certificates, :signature

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

        def to_h
          {
            version: @version,
            body: @body,
            signature: @signature,
            certificates: @certificates
          }.compact
        end

        def inspect
          to_h.ai
        end

        def to_bytes
          @data.to_der
        end

        def to_tree
          node = Helpers::TreeNode.new(Models::IMG4.key_name(:IM4M).ai)

          node.children << Helpers::TreeNode.new("Version: #{@version.ai}")
          node.children << @body.to_tree if @body
          node.children << Helpers::TreeNode.new('Signature', [Helpers::TreeNode.new(@signature.ai)]) if @signature
          node.children << Helpers::TreeNode.new('Certificates', @certificates.map(&:to_tree)) if @certificates

          node
        end

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

        def signed_data
          @data.value[2].to_der
        end

        def raw_hashes
          [
            { kind: :manifest_hash, value: to_bytes },
            { kind: :signed_data, value: signed_data }
          ]
        end

        def firmware_tag(type)
          @body.to_h[:MANB][type.to_sym]
        end

        def public_keys
          @certificates.to_h do |certificate|
            [certificate.subject.to_s, certificate.public_key]
          end
        end
      end
    end
  end
end
