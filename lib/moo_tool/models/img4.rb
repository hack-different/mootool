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

        def self.load(path)
          data = ::File.binread(path)
          File.new(data)
        end

        def parse_certificates(certificates)
          certificates.map do |certificate|
            OpenSSL::X509::Certificate.new(certificate)
          end
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
            @content[:im4p] = {
              img4_type: @value[1],
              build: @value[2],
              payload: MooTool::Decompressor.new(@value[3])
            }
          when 'IM4M'
            @content[:im4m] = {
              version: @value[1],
              MANB: @value[2][0]['MANB'],
              signature: Models::Digest.create(@value[3]),
              certificate: parse_certificates(@data.value[4])
            }
          when 'IMG4'
            @value[2].each_with_index do |entry, index|
              case entry[0]
              when 'IM4M'
                @content[:im4m] = {
                  version: entry[1],
                  MANB: entry[2][0],
                  signature: Models::Digest.create(entry[3]),
                  certificate: parse_certificates(@data.value[2].value[index].value[4]),
                }
              when 'IM4P'
                @content[:im4p] = {
                  im4p_type: entry[1],
                  version: entry[2],
                  manifest: entry[3],
                  payload: entry[4]
                }
              end
            end
          when 'secb'
            @content[:secb] = @value.drop(1).map do |entry|
              case entry[0]
              when 'trst', 'rssl'
                { entry[0] => Certificate.new(construct(OpenSSL::ASN1.decode(entry[1]))[0] )}
              when 'rvok'
                { entry[0] => entry[1] }
              when 'trpk'
                { entry[0] => entry.drop(1) }
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
            raise "Unknown IMG4 type #{@type}"
          end
        end

        def parse_im4m(value)
          @version = value[1]
          manifest = value[2]
          case manifest
          when 'MANB'
            parse_pair manifest.value[1].value[0].value[0]
            @manifest = parse_manifest manifest.value[1]
            @signature = @data.value[3].value
            @certificate = Models::Certificate.new @data.value[4].value
          end
        end

        def parse_manifest(manifest)
          @manp = manifest.value.first
          @elements = manifest.value.drop(1).map do |e|
            parse_element e.value[0]
          end.reduce(&:merge).transform_values do |value|
            value.map { |p| parse_element p.value[0] }.reduce(&:merge)
          end
          @elements = @elements.deep_transform_values do |element|
            case element
            when String
              if [384].include?(element.length * 8)
                element
              else
                element
              end
            else
              element
            end
          end
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
          @content
        end

        def hashes
          result = [ @hash ]
          if @content[:im4p]
            result += @content[:im4p][:payload].hashes
          end
          result
        end

        def print(friendly)
          if friendly
            mappings = IMG4.mappings
            output = print_value.deep_transform_keys do |key|
              new_key = mappings.dig(key.to_s, 'title') || mappings.dig(key.to_s, 'description') || key
              new_key.to_sym
            end
            output = output.deep_transform_values do |value|
              case value
              when MooTool::Models::Digest
                value.file_names @file_index
              else
                value
              end
            end
            ap output
          else
            ap print_value
          end
        end

      end

      def self.mappings
        mappings_data = YAML.load_file('/Users/rickmark/Sites/apple-knowledge/_data/img4.yaml')
        mappings_data['property_collections'].map { |p| mappings_data[p] }.reduce(&:merge)
      end
    end
  end
end
