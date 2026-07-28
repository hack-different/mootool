# typed: false
# frozen_string_literal: true

require 'openssl'
require 'amazing_print'
require_relative 'decompressor'

module MooTool
  module Models
    # Module for Apple's IMG4 encryption and signing format
    module IMG4
      def self.parse_4cc(input)
        input.map do |value|
          value.b.unpack1('N')
        end
      end

      # An instance of a IMG4 file
      class File
        attr_reader :payload, :manifest, :file_index

        include Helpers::IMG4

        DER_PAYLOADS = %w[trst].freeze

        def self.load(path)
          data = ::File.binread(path)
          File.new(data)
        end

        def parse_signature(signature)
          size = signature.is_a?(Models::Digest) ? signature.value.size : signature.size
          if size > 128
            # RSA Signature
            signature.hint = 'RSASignature' if signature.respond_to?(:hint)
            signature
          else
            construct(OpenSSL::ASN1.decode(signature))
          end
        end

        def parse_certificates(certificates)
          certificates.map do |certificate|
            case certificate
            when Models::Digest
              Models::Certificate.new OpenSSL::X509::Certificate.new(certificate.value)
            else
              Models::Certificate.new OpenSSL::X509::Certificate.new(certificate)
            end
          end
        end

        def to_h
          @content
        end

        def initialize(der)
          @file_index = Models::FileIndex.load '/Users/rickmark/Desktop/index.json'

          @hash = Models::Digest.create(::Digest::SHA384.digest(der))
          @data = OpenSSL::ASN1.decode(der)
          @value = construct(@data)
          @type = @value.first
          @content = {}

          case @type
          when 'IM4P'
            @payload = MooTool::Decompressor.new(@data.value[3].value)
            @content[:IM4P] = {
              img4_type: @value[1],
              build: @value[2],
              payload: @payload
            }
          when 'IM4M'
            @content[:IM4M] = {
              version: @value[1],
              **@value[2].map(&:to_h).reduce({}, :merge),
              signature: parse_signature(@value[3]),
              certificate: parse_certificates(@data.value[4])
            }
          when 'IMG4'
            entries = @value.drop(1)
            entries.each_with_index do |entry, index|
              case entry[0]
              when 'IM4M'
                extract_img4_im4m(entry, @data.value[index + 1])
              when 'IM4P'
                parse_img4_im4p(entry, @data.value[index + 1])
              when Array
                entry.each_with_index do |subentry, _subindex|
                  case subentry[0]
                  when 'IM4M'
                    extract_img4_im4m(subentry, @data.value[index + 1].value[0].value[4])
                  end
                end
              end
            end
          when 'secb'
            @content[:secb] = @value.drop(1).map do |entry|
              case entry[0]
              when 'trst', 'rssl'
                { entry[0].to_sym => parse_certificates(entry.drop(1)) }
              when 'rvok'
                { entry[0].to_sym => entry[1] }
              when 'trpk'
                { entry[0].to_sym => entry.drop(1).map { |e| Models::Digest.create(e) } }
              end
            end.reduce(&:merge)
          when 'comb'
            @content[:comb] = @value.drop(1).map do |entry|
              case entry[0]
              when 'fdrd'
                { entry[0] => File.new(entry[1]).print_value }
              end
            end
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
          @content.merge(hashes: hashes).to_h
        end

        def hashes
          result = [@hash]
          result += @payload.hashes if @payload

          result.uniq(&:value)
        end

        def print(friendly)
          output = print_value.deep_symbolize_keys
          if friendly
            mappings = IMG4.mappings

            output.deep_transform_keys! do |key|
              new_key = mappings.dig(key.to_s, 'title') || mappings.dig(key.to_s, 'description') || key
              new_key.to_sym
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

        private

        def extract_img4_im4m(entry, data_path)
          @content[:im4m] = {
            version: entry[1],
            **entry[2].map(&:to_h).reduce(&:merge),
            signature: parse_signature(entry[3]),
            certificates: parse_certificates(data_path)
          }
        end

        def parse_img4_im4p(entry, data_path)
          payload_data = data_path.value[3].value
          @payload = MooTool::Decompressor.new(payload_data)

          @content[:im4p] = {
            im4p_type: entry[1],
            version: entry[2],
            payload: @payload
          }
        end
      end

      def self.mappings
        mappings_data = YAML.load_file('/Users/rickmark/Sites/apple-knowledge/_data/img4.yaml')
        mappings_data['property_collections'].map { |p| mappings_data[p] }.reduce(&:merge).with_indifferent_access
      end
    end
  end
end
