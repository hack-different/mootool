# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    class CertificateIndex
      attr_accessor :index
      def initialize(path = nil)
        @index = {}
      end

      def self.current
        unless @certificate_index
          @certificate_index = CertificateIndex.new
          Models::FileIndex.current.index.each do |file|
            Models.file_guesser(file.fullname)
          end
        end
        @certificate_index
      end

      def matching_key(key)
        key = Certificate.formatted_public_key(key)
        index.select do |_hash, certificate|
          key == certificate.formatted_public_key
        end.map do |_hash, certificate|
          { subject: certificate.subject.to_s, fingerprint: certificate.fingerprint, hash: certificate.hash}
        end.uniq do |entry|
          entry[:hash].value
        end
      end

      def with_identifier(id)
        index.select do |_hash, certificate|
          certificate.identifiers.include? id
        end
      end

      def self.add_certificate(certificate)
        current.index[certificate.hash] = certificate
      end

      def save(path)
        data = index.map do |hash, certificate|
          pkey = certificate.formatted_public_key
          pkey = case pkey
                 when Models::Digest
                   pkey.shasum
                 when Models::Certificate::ECCPublicKey
                   point_data = pkey.point.to_octet_string(:uncompressed)
                   cartisian_data = point_data[1..-1]
                   x_data, y_data = cartisian_data[0..cartisian_data.size/2], cartisian_data[cartisian_data.size/2..-1]
                   {
                     curve: pkey.curve.curve_name,
                     point: Models::Digest.create(point_data).hex,
                     x: Models::Digest.create( x_data).hex,
                     y: Models::Digest.create( y_data).hex
                   }
                 else
                   pkey.to_h
                 end

          {
            hash: hash.shasum,
            pkey: pkey,
            **certificate.to_h,
          }
        end

        json = JSON.pretty_generate(data)
        File.write(path, json)
      end
    end

    class Certificate
      include Helpers::IMG4

      attr_reader :hash, :fingerprint

      def self.load_oid_map(path)
        YAML.load_file(path).deep_symbolize_keys
      end

      APPLE_OID_MAP = load_oid_map('/Users/rickmark/Sites/apple-knowledge/_data/pki.yaml')

      def initialize(certificate)
        @certificate = certificate
        @hash = Models::Digest.digest(@certificate.to_der)
        @fingerprint = ::Digest::SHA1.hexdigest(@certificate.to_der).scan(/../).join(":").upcase

        @extensions = certificate.extensions.map do |extension|
          parse_extension(extension)
        end.reduce(&:merge)

        CertificateIndex.add_certificate(self)
      end

      def identifiers
        [ @fingerprint, @extensions[:subjectKeyIdentifier] ]
      end


      def formatted_public_key(find_matches: false)
        Certificate.formatted_public_key(self.public_key, find_matches: find_matches)
      end

      def openssl_certificate
        @certificate
      end

      def public_key
        @certificate.public_key
      end

      def self.load(path)
        new(File.read(path))
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
                when :authorityKeyIdentifier
                  aki = extension.value.include?("\n") ? extension.value.split("\n") : extension.value
                  matches = CertificateIndex.current.with_identifier(aki)

                  if matches.any?
                    { id: aki, matches: matches }
                  else
                    aki
                  end
                when :subjectKeyIdentifier
                  extension.value.include?("\n") ? extension.value.split("\n") : extension.value
                when :'1.2.840.113635.100.6.16'
                  construct(OpenSSL::ASN1.decode(extension.value_der)).split(';')
                when :appleDeviceAttestationKeyUsageProperties
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
                when :appleDeviceAttestationDeviceOSInformation, :appleFactoryTrustModeSigning, :appleDeviceAttestationHardwareProperties
                  resequence(construct(OpenSSL::ASN1.decode(extension.value_der))).transform_keys do |key|
                    if key.is_a?(Symbol)
                      key
                    else
                      tag = APPLE_OID_MAP.dig(:extension_tags, key) || { name: key }
                      tag[:name].respond_to?(:to_sym) ? tag[:name].to_sym : tag[:name]
                    end
                  end.transform_values(&:first)
                else
                  case oid_properties[:type]
                  when :img4
                    IMG4::File.new(extension.value_der).to_h
                  when :scalar
                    construct(OpenSSL::ASN1.decode(extension.value_der)).first
                  when :hash
                    construct(OpenSSL::ASN1.decode(extension.value_der)).map(&:to_h).reduce(&:merge)
                  when :sequence
                    resequence(construct(OpenSSL::ASN1.decode(extension.value_der)))
                  else
                    construct(OpenSSL::ASN1.decode(extension.value_der))
                  end
                end

        if extension.critical?
          { oid_properties[:name].to_sym => { critical: extension.critical?, value: value } }
        else
          { oid_properties[:name].to_sym => value }
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
          Models::Digest.create key.n.to_i, 'RSAPublicKey'
        else
          key
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

      def to_h
        result = { subject: @certificate.subject.to_s, issuer: @certificate.issuer.to_s }

        result[:key_id] = key_id if key_id
        result[:public_key] = formatted_public_key(find_matches: true)
        result[:fingerprint] = @fingerprint

        result[:extensions] = @extensions
        result
      end

      def inspect
        to_h
      end

      class ECCSignature
        include Helpers::IMG4

        attr_reader :value

        def initialize(signature)
          @value = signature
          @values = construct(OpenSSL::ASN1.decode(signature))
          @r, @s = @values
        end

        def to_h
          { r: @r, s: @s }
        end

        def self.create(signature)
          size = signature.is_a?(Models::Digest) ? signature.value.size : signature.size
          if size > 128
            # RSA Signature
            signature.hint = 'RSASignature' if signature.respond_to?(:hint)
            signature
          else
            value = signature.respond_to?(:value) ? signature.value : signature
            ECCSignature.new(value)
          end
        end
      end

      class ECCPublicKey
        include Helpers::IMG4

        attr_reader :value, :curve, :point

        def initialize(key)
          if key.is_a?(OpenSSL::PKey::EC::Point)
            @value = key
            @curve = @value.group
            @point = @value
          else
            @value = OpenSSL::ASN1.decode(key)

            @curve = OpenSSL::PKey::EC::Group.new @value.value[0].value[1].value
            @point = OpenSSL::PKey::EC::Point.new @curve, @value.value[1].value
          end

        end

        def ==(other)
          case other
          when ECCPublicKey
            @curve == other.curve && @point == other.point
          when OpenSSL::PKey::EC
            @curve == other.group && @point = other.public_key
          end
        end
      end

      class ECIESEncryption
        include Helpers::IMG4

        attr_reader :point, :nonce

        def initialize(input, nonce)
          if input.is_a?(OpenSSL::PKey::EC::Point)
            # Recall that uncompressed points start with 0x04 to indicate that they are uncompressed
            # To get the proper X / Y we must trip this off first, then divide the string in half
            hex = input.to_octet_string(:uncompressed)[1..]
            pair = hex[0..(hex.length / 2)], hex[(hex.length / 2)..]
            @point = input
            @e_x = Models::Digest.create pair[0]
            @e_y = Models::Digest.create pair[1]

            @nonce = Models::Digest.create(nonce)
          else
            @values = construct(OpenSSL::ASN1.decode(input.value))
            @point = parse_point_any(OpenSSL::PKey::EC::Point.new(@values[0], @values[1]))
            @values = @values.map { |v| Models::Digest.create(v) }
            @values.each do |v|
              v.hint = 'ECCDH'
            end
            @e_x, @e_y, @nonce = @values
          end
        end

        def parse_point_any(point)
          mappings = %w[prime256v1 secp384r1].map do |group|
            group = OpenSSL::PKey::EC::Group.new(group)
            OpenSSL::PKey::EC::Point.new(group, point)
          rescue StandardError
            nil
          end

          mappings.compact.first
        end

        def group
          @point.group.curve_name
        end

        def to_h
          { e_x: @e_x.shasum, e_y: @e_y.shasum, n: @nonce.shasum }
        end

        def inspect
          to_h.ai
        end
      end
    end
  end
end
