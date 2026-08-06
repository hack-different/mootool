# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    # A wrapper around OpenSSL::X509::Certificate with additional fuctionality
    class Certificate
      PREFIX_MAP = ['keyid:', 'DirName:', 'serial:'].freeze

      include Helpers::IMG4
      include Helpers::Hashing

      attr_reader :digest, :fingerprint

      delegate :issuer, :subject, to: :@certificate

      APPLE_OID_MAP = AppleData::Schemas::PKI.new.oids.deep_symbolize_keys

      def initialize(certificate)
        @certificate = certificate
        @digest = to_hash(certificate.to_der)
        @fingerprint = ::Digest::SHA1.hexdigest(@certificate.to_der).scan(/../).join(':').upcase

        @extensions = certificate.extensions.map do |extension|
          parse_extension(extension)
        end.reduce(&:merge)

        CertificateIndex.add_certificate(self)
      end

      def identifiers
        [@fingerprint, @extensions[:subjectKeyIdentifier]]
      end

      def verify(public_key)
        @certificate.verify(public_key)
      rescue StandardError
        false
      end

      def formatted_public_key(find_matches: false)
        Certificate.formatted_public_key(public_key, find_matches: find_matches)
      end

      def openssl_certificate
        @certificate
      end

      def ==(other)
        @certificate == case other
                        when Certificate
                          other.openssl_certificate
                        else
                          other
                        end
      end

      def public_key
        @certificate.public_key
      end

      def self.load(path)
        file_data = File.read(path)
        if file_data.include?('-----BEGIN CERTIFICATE-----')
          file_data.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |text|
            ::MooTool::Models::Certificate.new OpenSSL::X509::Certificate.new(text)
          end
        else
          ::MooTool::Models::Certificate.new(OpenSSL::X509::Certificate.new(file_data))
        end
      end

      def self.oid_properties(oid)
        element = APPLE_OID_MAP[oid.to_sym]

        match ||= { name: oid.to_sym }

        if element
          match[:name] = element.to_s.to_sym
          match[:type] = element.type.to_sym if element.type
        end

        match
      end

      def self.oid_to_name(oid)
        oid = oid.to_sym
        result = APPLE_OID_MAP.dig(:oids, oid, :name) || oid
        result.to_sym
      end

      def parse_extension(extension)
        oid_properties = Certificate.oid_properties(extension.oid)
        value = case oid_properties[:name]
                when :basicConstraints
                  extension.value
                when :keyUsage
                  construct(OpenSSL::ASN1.decode(extension.value_der))
                when :authorityKeyIdentifier, :subjectKeyIdentifier
                  parse_identifiers extension
                when :appleKeyInstanceName
                  data = construct(OpenSSL::ASN1.decode(extension.value_der))
                  Certificate.parse_sik(data)
                when :appleSecureEnclaveFDRCommands
                  construct(OpenSSL::ASN1.decode(extension.value_der)).split(';').map do |entry|
                    command, value = entry.split(':')
                    direction, config = command.split('/')
                    { direction: direction, config: config, value: Certificate.parse_sik(value) }
                  end
                when :appleImg4Manifest
                  Models::IMG4::IMG4Manifest.new(OpenSSL::ASN1.decode(extension.value_der))
                when :appleImg4ManifestSpecification
                  IMG4::ManifestSpecification.new(extension.value_der)
                when :appleDeviceAttestationKeyUsageProperties
                  parse_apple_device_attestation(extension)
                when :appleDeviceAttestationDeviceOSInformation, :appleFactoryTrustModeSigning,
                  :appleDeviceAttestationHardwareProperties

                  parse_apple_sequence(extension)
                when :appleSomeSHA256Hash
                  Models::Digest.create extension.value
                else
                  parse_other_extension(oid_properties, extension)
                end

        if extension.critical?
          { oid_properties[:name].to_sym => { critical: extension.critical?, value: value } }
        else
          { oid_properties[:name].to_sym => value }
        end
      end

      def to_tree
        properties = { subject: @certificate.subject.to_s, issuer: @certificate.issuer.to_s }

        properties[:key_id] = key_id if key_id
        properties[:public_key] = formatted_public_key(find_matches: true)
        properties[:public_key_sha] = public_key_sha
        properties[:fingerprint] = @fingerprint

        node = Helpers::TreeNode.new("Certificate:#{digest.ai}")
        node.children << Helpers::TreeNode.new('Properties', [Helpers::TreeNode.new(properties.ai)])
        validation_nodes = validations[:validations].map { |v| Helpers::TreeNode.new(v.ai) }
        node.children << Helpers::TreeNode.new('Validations', validation_nodes)
        extension_nodes = @extensions.map do |id, e|
          result = e.is_a?(Hash) && e.key?(:value) ? e[:value] : e
          if result.respond_to?(:to_tree)
            Helpers::TreeNode.new(id, [result.to_tree])
          else
            Helpers::TreeNode.new(id, [Helpers::TreeNode.new(result.ai)])
          end
        end
        node.children << Helpers::TreeNode.new('Extensions', extension_nodes)
        node
      end

      def parse_identifiers(extension)
        identifiers = extension.value.include?("\n") ? extension.value.split("\n") : [extension.value]
        identifiers.map do |id|
          { id => CertificateIndex.current.with_identifier(id) }
        end.reduce(&:merge)
      end

      def parse_apple_sequence(extension)
        resequence(construct(OpenSSL::ASN1.decode(extension.value_der))).transform_keys do |key|
          if key.is_a?(Symbol)
            key
          else
            tag = APPLE_OID_MAP.dig(:extension_tags, key) || { name: key }
            tag[:name].respond_to?(:to_sym) ? tag[:name].to_sym : tag[:name]
          end
        end.transform_values(&:first)
      end

      def parse_apple_device_attestation(extension)
        result = construct(OpenSSL::ASN1.decode(extension.value_der))

        result.map do |item|
          if item.is_a?(Hash)
            item.to_h do |key, value|
              tag = APPLE_OID_MAP.dig(:extension_tags, key) || { name: key }
              tag = tag[:name].respond_to?(:to_sym) ? tag[:name].to_sym : tag[:name]
              [tag, value.first]
            end
          else
            item
          end
        end
      end

      def parse_other_extension(oid_properties, extension)
        case oid_properties[:type]
        when :img4
          IMG4::File.new(extension.value_der).to_h
        when :scalar
          construct(OpenSSL::ASN1.decode(extension.value_der)).first
        when :hashes
          construct(OpenSSL::ASN1.decode(extension.value_der)).map(&:to_h).reduce(&:merge)
        when :sequence
          resequence(construct(OpenSSL::ASN1.decode(extension.value_der)))
        else
          extension.value
        end
      end

      def self.parse_sik(key)
        key = case key
              when MooTool::Models::Digest
                key.value
              when UUIDTools::UUID
                key.raw
              when nil
                return nil
              else
                key
              end

        return key unless key.start_with? 'sik-'

        parts = key.split('-')
        if parts.size == 3
          { key_type: :sik, serial: parts[1], hash: Models::Digest.from_hex(parts[2]) }
        elsif parts.size == 4
          { key_type: :sik, chip: parts[1], ecid: parts[2], hash: Models::Digest.from_hex(parts[3]) }
        end
      end

      def resequence(input)
        input.map(&:to_h).reduce(&:merge)
      end

      def map_to_arrays(input)
        case input
        when OpenSSL::ASN1::Set, OpenSSL::ASN1::Sequence
          input.value.map { |e| map_to_arrays(e) }
        else
          input
        end
      end

      def parse_ds_name(name)
        map_to_arrays(name).flatten.each_slice(2).to_h.transform_keys(&:to_sym)
      end

      def self.formatted_public_key(key, find_matches: false)
        result_key = case key
                     when OpenSSL::PKey::EC, OpenSSL::PKey::EC::Point
                       ECCPublicKey.new key
                     when OpenSSL::PKey::RSA
                       RSAPublicKey.new key
                     else
                       { class: key.class, key: key }
                     end

        if find_matches
          matches = CertificateIndex.current.matching_key(key)
          if matches.any?
            { key: result_key, matches: matches }
          else
            result_key
          end
        else
          result_key
        end
      end

      def key_id
        common_name = @certificate.subject.to_a.to_h do |entry|
          [entry[0], entry[1]]
        end['CN']

        return unless /^[0-9a-z]*$/.match(common_name)

        Models::Digest.create [common_name].pack('H*')
      end

      def public_key_sha
        targets = [
          @certificate.public_key.to_der
        ]

        if @certificate.public_key.is_a?(OpenSSL::PKey::EC)
          targets << @certificate.public_key.public_key.to_octet_string(:uncompressed)
          targets << @certificate.public_key.public_key.to_octet_string(:compressed)
        end

        targets.map do |target|
          Models::Digest.create(::Digest::SHA384.digest(target))
        end
      end

      def validations
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
            valid: verify(validator_certificate.public_key)
          }
        end
        valid_certs = validations.select do |validation|
          validation[:valid] || validation[:subject] == issuer.to_s
        end

        {
          fingerprint: fingerprint,
          subject: subject.to_s,
          issuer: issuer.to_s,
          key_id: key_id,
          public_key_sha: public_key_sha,
          validations: valid_certs.uniq { |cert| cert[:digest].shasum }
        }
      end

      def to_h
        result = { subject: @certificate.subject.to_s, issuer: @certificate.issuer.to_s }

        result[:key_id] = key_id if key_id
        result[:public_key] = formatted_public_key(find_matches: true)
        result[:public_key_sha] = public_key_sha
        result[:fingerprint] = @fingerprint
        result[:validations] = validations

        result[:extensions] = @extensions
        result
      end

      def inspect
        to_h
      end
    end
  end
end
