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
        def initialize(input)
          @type = input.value[1].value
          @description = input.value[2].value
          @payload = MooTool::Decompressor.new(input.value[3].value)
        end

        def to_h
          { type: @type, description: @description, payload: @payload }
        end

        def inspect
          to_h.ai
        end

        def hashes
          @payload.hashes
        end
      end

      class IMG4Manifest
        include Helpers::IMG4

        def initialize(input)
          @data = input

          @version = @data.value[1].value.to_i
          @body = construct(@data.value[2])
          @signature = File.parse_signature(@data.value[3]) if @data.value[3]
          @certificates = File.parse_certificates(@data.value[4]) if @data.value[4]
        end

        def to_h
          { version: @version, body: @body, signature: @signature, certificates: @certificates }
        end

        def inspect
          to_h.ai
        end

        def hashes
          [ Models::Digest.create(::Digest::SHA384.digest(@data.to_der)) ]
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
            Models::Certificate.new OpenSSL::X509::Certificate.new(certificate)
          end
        end

        def to_h
          @content.transform_values do |value|
            value.respond_to?(:to_h) ? value.to_h : value
          end
        end



        def initialize(der, filename = nil)
          @file_index = Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
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
            @content[:IM4M] = IMG4Manifest.new(@data.value[2].value[0])
          when 'secb'
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

        def print_value
          result = @content.merge(hashes: hashes).to_h
          if result[:comb]
            result[:comb] = result[:comb].map { |k,v| [k, v.print_value] }.to_h
          end
          result
        end

        def hashes
          result = @hashes.dup

          if @content[:comb]
            result += @content[:comb].flat_map { |_k,v| v.hashes }
          end

          if @content[:IM4M]
            result += @content[:IM4M].hashes
          end

          if @content[:IM4P]
            result += @content[:IM4P].hashes
          end

          result.reject { |h| h.nil? }.uniq(&:value)
        end

        def print(friendly)
          output = print_value.deep_symbolize_keys
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
