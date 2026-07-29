# typed: false
# frozen_string_literal: true

require 'openssl'
require 'amazing_print'
require_relative 'decompressor'
require 'cfpropertylist'

module MooTool
  module Models
    # Module for Apple's IMG4 encryption and signing format
    module IMG4
      def self.parse_4cc(input)
        input.map do |value|
          value.b.unpack1('N')
        end
      end

      HASH_FILENAME = /(?<hash>\h{96})/

      class IMG4Payload
        include Helpers::IMG4

        attr_reader :signature

        KEYBAG_TYPES = {
          1 => :PROD,
          2 => :DEV
        }

        def initialize(input)
          @input = input
          @type = input.value[1].value
          @description = input.value[2].value
          @payload = MooTool::Decompressor.new(input.value[3].value)
          @keybag = parse_keybag(input.value[4]) if input.value[4]

          if input.value[5]
            @extensions = construct(input.value[5]).map do |extension|
              { extension[0] => extension[1].map{|v| v.to_h}.reduce({}, :merge) }
            end.reduce(&:merge)
          end
        end

        def parse_keybag(input)
          value = construct(OpenSSL::ASN1.decode(input))

          return value unless value.all? { |a| a.is_a?(OpenSSL::ASN1) }

          value.map do |keybag|
            iv = Models::Digest.create(keybag[1].raw, 'IV')
            { KEYBAG_TYPES[keybag[0]] => { iv: iv, key: keybag[2] } }
          end.reduce(&:merge)
        end

        def to_h
          result = { type: @type, description: @description, payload: @payload }

          result[:keybag] = @keybag if @keybag
          result[:extensions] = @extensions if @extensions
          result
        end

        def inspect
          to_h.transform_values do |value|
            value.inspect
          end.ai
        end

        def to_bytes
          @input.to_der
        end

        def hashes
          results = [OpenSSL::Digest::SHA384.digest(to_bytes)]
          @payload.hashes.each do |hash|
            results << hash
          end
          results.uniq.map { |h| Models::Digest.create(h)}
        end
      end

      class IMG4Manifest
        include Helpers::IMG4

        attr_reader :certificates, :signature

        def initialize(input)
          @input = input

          if @input.value.size == 1
            @data = input.value[0]
          else
            @data = input
          end

          @version = @data.value[1].value.to_i
          @body = construct(@data.value[2])
          @signature = File.parse_signature(@data.value[3]) if @data.value[3]
          @certificates = File.parse_certificates(@data.value[4]) if @data.value[4]
        end

        def to_h
          {
            version: @version,
            body: @body,
            signature: @signature,
            certificates: @certificates
          }
        end

        def inspect
          to_h.ai
        end

        def to_bytes
          @input.to_der
        end

        def hashes
          [
            Models::Digest.create(::Digest::SHA384.digest(to_bytes)),
            Models::Digest.create(::Digest::SHA384.digest(@data.to_der)),
            Models::Digest.create(::Digest::SHA384.digest(@data.value[2].to_der))
          ]
        end
      end

      # An instance of a IMG4 file
      class File
        attr_reader :payload, :manifest, :file_index

        include Helpers::IMG4

        DER_PAYLOADS = %w[trst].freeze

        def self.load(path)
          data = ::File.binread(path)
          File.new(data, path)
        end

        def self.parse_signature(signature)
          signature = signature.value if signature.is_a?(OpenSSL::ASN1::OctetString)
          if signature.size > 128
            Models::Digest.create(signature, 'RSASignature')
          else
            ::MooTool::Models::Certificate::ECCSignature.create(signature)
          end
        end

        def self.parse_certificates(certificates)
          certificates.map do |certificate|
            certificate_data = certificate.value if certificate.is_a?(Models::Digest)
            certificate_data = certificate.to_der if certificate.respond_to?(:to_der)
            Models::Certificate.new OpenSSL::X509::Certificate.new(certificate_data)
          end
        end

        def to_h
          content = @content.transform_values do |value|
            value.inspect
          end

          content[:file_type] = @type
          content[:hashes] = self.hashes
          content
        end

        def initialize(der, filename = nil)
          Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
          @filename = filename

          raw_data = der.is_a?(Models::Digest) ? der.value : der

          @hashes = [Models::Digest.create(::Digest::SHA384.digest(raw_data))]
          @data = OpenSSL::ASN1.decode(raw_data)
          @type = @data.value[0].value
          @content = {}

          case @type
          when 'IM4P'
            @content[:IM4P] = IMG4Payload.new(@data)
          when 'IM4M'
            @content[:IM4M] = IMG4Manifest.new(@data)
          when 'IMG4'
            @content[:IM4P] = IMG4Payload.new(@data.value[1])
            @content[:IM4M] = IMG4Manifest.new(@data.value[2])
          when 'secb'
            @value = construct(@data)
            @content[:secb] = @value.drop(1).map do |entry|
              case entry[0]
              when 'trst', 'rssl'
                { entry[0].to_sym => File.parse_certificates(entry.drop(1)) }
              when 'rvok'
                { entry[0].to_sym => entry[1] }
              when 'trpk'
                { entry[0].to_sym => entry.drop(1).map { |e| Certificate::ECCPublicKey.new e } }
              end
            end.reduce(&:merge)
          when 'comb'
            @content[:comb] = @value.drop(1).map do |entry|
              { entry[0] => File.new(entry[1]) }
            end.reduce(&:merge)
          else
            @content = @value.map(&:to_h).reduce(&:merge)
          end

          #@content[:validity] = validate_signature
        end

        def validted_certificate_chain
          @content[:IM4M].certificates.last
        end

        def validate_signature
          leaf_certificate = validted_certificate_chain
          [ OpenSSL::Digest.new('SHA384'), OpenSSL::Digest.new('SHA256')].flat_map do |digest|

          values = %i[IM4M IM4P].map do |kind|
            @content[kind]&.to_bytes
          end.compact

          hashes = values.map do |value|
            OpenSSL::Digest::SHA384.digest(value)
          end.compact

          signatures = %i[IM4P IM4M].map do |kind|
            signature = @content[kind]&.signature
            signature.respond_to?(:value) ? signature.value : signature
          end.compact

          signatures.flat_map do |signature|
            value_result = values.map do |value|
              { digest.hexdigest(value) => leaf_certificate.public_key.verify(digest, signature, value) }
            end

            hashes_result = hashes.map do |hash|
              { digest.hexdigest(hash) => leaf_certificate.public_key.verify(digest, signature, hash) }
            end

            hash_hashes_result = hashes.map do |hash|
              { digest.hexdigest(hash) => leaf_certificate.public_key.verify(digest, signature, digest.digest(hash)) }
            end

            join_result = [
              { digest.hexdigest(hashes.join) => leaf_certificate.public_key.verify(digest, signature, hashes.join) }
            ]

            value_result + hashes_result + hash_hashes_result + join_result
          end
          end.reduce(&:merge)
        end

        def inspect
          @content
        end

        def parse_element(element)
          { element.value[0].value.to_sym => element.value[1].value }
        end

        def parse_pair(input)
          input.value.to_a.each_slice(2).to_h do |key, value|
            [key.value, value]
          end
        end

        def payload?
          !@payload.nil?
        end

        def manifest?
          !@manifest.nil?
        end

        def basename
          basename = ::File.basename(@path)
          extension = ::File.extname(basename)
          "#{basename.chomp(extension)}.#{@type}"
        end

        def extract_payload
          output_path = ::File.join(::File.dirname(@path), basename)
          ::File.write(output_path, @payload)
        end

        def hashes
          result = @hashes.dup

          result += @content[:comb].flat_map { |_k, v| v.hashes } if @content[:comb]

          result += @content[:IM4M].hashes if @content[:IM4M]

          result += @content[:IM4P].hashes if @content[:IM4P]

          result.map { |h| h.respond_to?(:value) ? h.value : h }.uniq.map { |h| Models::Digest.create(h)}
        end

        def print(friendly)
          output = inspect.dup.deep_symbolize_keys
          if friendly
            mappings = IMG4.mappings

            output.deep_transform_keys! do |key|
              new_key = mappings.dig(key.to_s, 'title') || mappings.dig(key.to_s, 'description') || key
              new_key.respond_to?(:to_sym) ? new_key.to_sym : new_key
            end

            output.deep_transform_values! do |value|
              case value
              when MooTool::Models::Digest
                value.file_names @file_index
              when MooTool::Helpers::FirmwareEntry
                value.file_names @file_index
              else
                value
              end
            end
          end

          ap(output)
        end
      end

      def self.mappings
        mappings_data = YAML.load_file('/Users/rickmark/Sites/apple-knowledge/_data/img4.yaml')
        mappings_data['property_collections'].map { |p| mappings_data[p] }.reduce(&:merge).with_indifferent_access
      end
    end
  end
end
