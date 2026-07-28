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

      # An instance of a IMG4 file
      class File
        attr_reader :payload, :manifest, :file_index

        include Helpers::IMG4

        DER_PAYLOADS = %w[trst].freeze

        def self.load(path)
          data = ::File.binread(path)
          File.new(data, path)
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



        def initialize(der, filename = nil)
          @file_index = Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
          @filename = filename

          raw_data = der.is_a?(Models::Digest) ? der.value : der

          @hashes = [Models::Digest.create(::Digest::SHA384.digest(raw_data))]
          @data = OpenSSL::ASN1.decode(raw_data)
          @value = construct(@data)
          @type = @value.first
          @content = {}

          #filename_match = HASH_FILENAME.match(@filename)
          #@hashes << Models::Digest.new([filename_match[:hash]].pack('H*')) if filename_match

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
              signature: Models::Certificate::ECCSignature.create(@value[3]),
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
                    extract_img4_im4m(subentry, @data.value[index + 1].value[0])
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
          result += @payload.hashes if @payload

          if @content[:comb]
            result += @content[:comb].flat_map { |k,v| v.hashes }
          end

          if @content[:IM4M]
            result.append(@content.dig(:IM4M, :MANB, :lpol, :DGST))
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

        private

        def extract_img4_im4m(entry, data_path)
          @content[:IM4M] = {
            version: entry[1],
            **entry[2].map(&:to_h).reduce(&:merge),
            signature: ::MooTool::Models::Certificate::ECCSignature.create(entry[3]),
            certificates: parse_certificates(data_path.value[4])
          }
        end

        def parse_img4_im4p(entry, data_path)
          payload_data = data_path.value[3].value
          @payload = MooTool::Decompressor.new(payload_data)

          @content[:IM4P] = {
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
