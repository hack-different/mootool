# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    # A wrapper around OpenSSL::X509::Certificate with additional fuctionality
    class Certificate
      include Helpers::IMG4
      include Helpers::Hashing

      attr_reader :digest, :fingerprint

      def self.load_oid_map
        YAML.load_file(File.join(DATA_PATH, 'pki.yaml')).deep_symbolize_keys
      end

      APPLE_OID_MAP = load_oid_map

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

      def validate(public_key)
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
        case other
        when Certificate
          @certificate == other.openssl_certificate
        when OpenSSL::X509::Certificate
          @certificate == other
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
        match = APPLE_OID_MAP.dig :oids, oid.to_sym

        match ||= { name: oid.to_sym }
        match[:name] = (match[:name] || oid).to_sym
        match[:type] = match[:type].to_sym if match[:type]
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
                when :'1.2.840.113635.100.6.17'
                  data = construct(OpenSSL::ASN1.decode(extension.value_der))
                  Certificate.parse_sik(data)
                when :'1.2.840.113635.100.6.16'
                  construct(OpenSSL::ASN1.decode(extension.value_der)).split(';').map do |entry|
                    command, value = entry.split(':')
                    direction, config = command.split('/')
                    { direction: direction, config: config, value: Certificate.parse_sik(value) }
                  end
                when :appleDeviceAttestationKeyUsageProperties
                  parse_apple_device_attestation(extension)
                when :appleDeviceAttestationDeviceOSInformation, :appleFactoryTrustModeSigning,
                  :appleDeviceAttestationHardwareProperties

                  parse_apple_sequence(extension)
                else
                  parse_other_extension(oid_properties, extension)
                end

        if extension.critical?
          { oid_properties[:name].to_sym => { critical: extension.critical?, value: value } }
        else
          { oid_properties[:name].to_sym => value }
        end
      end

      def parse_identifiers(extension)
        identifiers = extension.value.include?("\n") ? extension.value.split("\n") : [extension.value]
        identifiers.map do |id|
          { id => CertificateIndex.current.with_identifier(id) }
        end
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
          construct(OpenSSL::ASN1.decode(extension.value_der))
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
                       Models::Digest.create key.to_der, 'RSAPublicKey'
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

      def issuer
        @certificate.issuer
      end

      def subject
        @certificate.subject
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
            valid: validate(validator_certificate.public_key)
          }
        end
        valid_certs = validations.select do |validation|
          validation[:valid] || validation[:subject] == issuer.to_s
        end

        {
          subject.to_s => {
            issuer: issuer.to_s,
            validations: valid_certs.uniq { |cert| cert[:digest].shasum }
          }
        }
      end

      def to_h
        result = { subject: @certificate.subject.to_s, issuer: @certificate.issuer.to_s }

        result[:key_id] = key_id if key_id
        result[:public_key] = formatted_public_key(find_matches: true)
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
