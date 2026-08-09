# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    # A wrapper around OpenSSL::X509::Certificate with additional functionality for Apple PKI
    #
    # This class provides enhanced parsing of Apple-specific X.509 extensions,
    # certificate validation, and tree-based rendering.
    class Certificate
      # Map of prefixes used in certificate identifiers
      PREFIX_MAP = ['keyid:', 'DirName:', 'serial:'].freeze

      include Helpers::IMG4
      include Helpers::Hashing

      # @return [Models::Digest] The digest of the certificate's DER encoding.
      attr_reader :digest
      # @return [String] The SHA-1 fingerprint of the certificate.
      attr_reader :fingerprint

      delegate :issuer, :subject, to: :@certificate

      # Map of Apple OIDs to their symbolic names and types
      APPLE_OID_MAP = AppleData::Schemas::PKI.new.oids.with_indifferent_access

      # Initializes a new Certificate object
      #
      # @param certificate [OpenSSL::X509::Certificate] The underlying OpenSSL certificate object.
      def initialize(certificate, skip_index: false)
        @certificate = certificate
        @digest = to_hash(certificate.to_der)
        @fingerprint = ::Digest::SHA1.hexdigest(@certificate.to_der).scan(/../).join(':').upcase

        @extensions = certificate.extensions.map do |extension|
          parse_extension(extension)
        end.reduce(&:merge)

        Models::CertificateIndex.add_certificate(self) unless skip_index
      end

      # Returns identifying strings for the certificate (fingerprint and subject key identifier)
      #
      # @return [Array<String>] List of identifiers.
      def identifiers
        [@fingerprint, @extensions[:subjectKeyIdentifier]]
      end

      # Verifies the certificate's signature using a public key
      #
      # @param public_key [OpenSSL::PKey::PKey] The public key to verify against.
      # @return [Boolean] True if the signature is valid.
      def verify(public_key)
        @certificate.verify(public_key)
      rescue StandardError
        false
      end

      # Returns a formatted representation of the certificate's public key
      #
      # @param find_matches [Boolean] Whether to search for matching certificates in the index.
      # @return [Object] The formatted public key.
      def formatted_public_key(find_matches: false)
        Certificate.formatted_public_key(public_key, find_matches: find_matches)
      end

      def raw
        @certificate.to_der
      end

      # Returns the underlying OpenSSL certificate object
      #
      # @return [OpenSSL::X509::Certificate]
      def openssl_certificate
        @certificate
      end

      # Compares this certificate with another
      #
      # @param other [Certificate, OpenSSL::X509::Certificate] The object to compare with.
      # @return [Boolean] True if the certificates are equal.
      def ==(other)
        @certificate == case other
                        when Certificate
                          other.openssl_certificate
                        else
                          other
                        end
      end

      # Returns the public key of the certificate
      #
      # @return [OpenSSL::PKey::PKey]
      def public_key
        @certificate.public_key
      end

      # Loads one or more certificates from a file
      #
      # @param path [String, Pathname] Path to the certificate file (PEM or DER).
      # @return [Certificate, Array<Certificate>] The loaded certificate(s).
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

      # Looks up properties for a given OID
      #
      # @param oid [String, Symbol] The OID to look up.
      # @return [Hash] Properties of the OID (name, type).
      def self.oid_properties(oid)
        element = APPLE_OID_MAP[oid.to_sym]

        match ||= { name: oid.to_sym }

        if element
          match[:name] = element.to_s.to_sym
          match[:type] = element.type.to_sym if element.type
        end

        match
      end

      # Maps an OID to its symbolic name
      #
      # @param oid [String, Symbol] The OID to map.
      # @return [Symbol] The symbolic name.
      def self.oid_to_name(oid)
        oid = oid.to_sym
        result = APPLE_OID_MAP.dig(:oids, oid, :name) || oid
        result.to_sym
      end

      # Parses a single certificate extension
      #
      # @param extension [OpenSSL::X509::Extension] The extension to parse.
      # @return [Hash] The parsed extension data.
      def parse_extension(extension)
        oid_properties = Certificate.oid_properties(extension.oid)
        value = case oid_properties[:name]
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
                when :basicConstraints, :keyUsage, :appleDeviceAttestationKeyUsageProperties, :appleDeviceAttestationDeviceOSInformation, :appleFactoryTrustModeSigning,
                  :appleDeviceAttestationHardwareProperties, :applePinningAllowTestCertsUCRT
                  RASN2.parse(extension.value_der)
                when :appleImg4ManifestSpecification
                  Schemas::ASN1::ManifestSpecification.parse(extension.value_der)
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

      # Converts the certificate to a TreeNode structure for display
      #
      # @return [Helpers::TreeNode] The tree representation.
      def to_tree
        properties = { subject: @certificate.subject.to_s, issuer: @certificate.issuer.to_s }

        properties[:key_id] = key_id if key_id
        properties[:public_key] = formatted_public_key(find_matches: true)
        properties[:public_key_sha] = public_key_sha
        properties[:fingerprint] = @fingerprint

        node = Helpers::TreeNode.new("Certificate:#{digest.ai}", properties: properties)
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

      # Parses identifiers from an extension value
      #
      # @param extension [OpenSSL::X509::Extension] The extension containing identifiers.
      # @return [Hash] Map of identifier string to certificate list.
      def parse_identifiers(extension)
        identifiers = extension.value.include?("\n") ? extension.value.split("\n") : [extension.value]
        identifiers.map do |id|
          { id => CertificateIndex.current.with_identifier(id) }
        end.reduce(&:merge)
      end

      # Parses an Apple-specific sequence extension
      #
      # @param extension [OpenSSL::X509::Extension] The extension to parse.
      # @return [Hash] The parsed sequence data.
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

      # Parses Apple device attestation key usage properties
      #
      # @param extension [OpenSSL::X509::Extension] The extension to parse.
      # @return [Array] The parsed attestation properties.
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

      # Parses a SIK (Secure Instance Key) identifier string
      #
      # @param key [String, Models::Digest, UUIDTools::UUID, nil] The SIK key to parse.
      # @return [Hash, String, nil] The parsed SIK properties or the original key.
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

      # Returns a formatted public key, optionally with matches from the certificate index
      #
      # @param key [OpenSSL::PKey::PKey] The public key to format.
      # @param find_matches [Boolean] Whether to look for matching certificates.
      # @return [Object] The formatted public key.
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
            { key: result_key, matches: matches.uniq { |match| match[:hash].hex } }
          else
            result_key
          end
        else
          result_key
        end
      end

      # Extracts the Key ID from the certificate's subject Common Name
      #
      # @return [Models::Digest, nil] The extracted Key ID.
      def key_id
        common_name = @certificate.subject.to_a.to_h do |entry|
          [entry[0], entry[1]]
        end['CN']

        return unless /^[0-9a-z]*$/.match(common_name)

        Models::Digest.create [common_name].pack('H*')
      end

      # Calculates SHA-384 digests of the public key in various formats
      #
      # @return [Array<Models::Digest>] List of digests.
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

      def self_signed?
        verify(public_key)
      end

      def missing_root?
        validations[:validations].any? == false
      end

      # Performs various validations on the certificate against the index
      #
      # @return [Hash] Validation results.
      def validations
        validator_certs = CertificateIndex.current.index.sort_by do |_hash, validator_certificate|
          validator_certificate.subject.to_s
        end
        validator_certs = validator_certs.uniq { |_hash, cert| cert.digest }

        validations = validator_certs.map do |_hash, validator_certificate|
          {
            subject: validator_certificate.subject.to_s,
            issuer: validator_certificate.issuer.to_s,
            self_digest: (validator_certificate.digest == digest),
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

      def self.read(data)
        data = data.value if data.is_a?(Models::Digest)
        certificate = OpenSSL::X509::Certificate.load(data)
        certificate = certificate.first if certificate.is_a?(Array)
        new(certificate, skip_index: true)
      end

      # Converts the certificate to a Hash representation
      #
      # @return [Hash]
      def to_h
        result = { subject: @certificate.subject.to_s, issuer: @certificate.issuer.to_s }

        result[:key_id] = key_id if key_id
        result[:public_key] = formatted_public_key(find_matches: true)
        result[:public_key_sha] = public_key_sha
        result[:fingerprint] = @fingerprint
        result[:validations] = validations
        result[:self_signed] = self_signed?

        result[:extensions] = @extensions
        result
      end

      # Returns a Hash representation for inspection
      #
      # @return [Hash]
      def inspect
        to_h
      end
    end
  end
end
