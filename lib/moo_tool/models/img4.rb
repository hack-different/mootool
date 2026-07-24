# typed: false
# frozen_string_literal: true

require 'openssl'
require 'amazing_print'
require_relative 'decompressor'

module MooTool

  module Models
    # Module for Apple's IMG4 encryption and signing format
    module IMG4
      HASH_LENGTHS = [160, 224, 256, 384, 512]
      OCTET_TAGS = [1952607603,1162037572,1128810832,1802856804,1987406180]
      KVP_TAGS = [1430538564,1668047219,1668178792,1717790832,1852075885,1885435493,1937013104,1954115685,1986950509,1919904880,1969841261,1953723504,1952543856,1952540532,1935960944,1936881262,1936618854,1936617326,1886549104,1634758006,1702061165,1112425288,1701261422,1952607603,1869639780,1162891855,1163085123,1163085123,1937010279,1919970920,1819307624,1819244133,1129337423,1162037572,1112494660,1129530691,1853057384,1396985677,1819239023,1128616015,1802856804,1128810832,1162560857,1145525076,1936746856,1987406180,1752329328]
      SEQUENCE_TAGS = [1667329907,1667330937,1668509555,1668510585,1953653601,1953653619,1919185771,1920234339,1819307884,1296125506,1919186034,1919247213,1919317107,1919644270,1920168052,1920232821,1920234104,1919181680,1919181618,1919117679,1768059763,1768058740,1768056163,1734768742,1651733603,1650553926,1650553904,1650553905,1635082868,1634693222,1296125520,1886217062,1886220390,1918987891,1936027753,1937008433,1936749677,1768055924,1735162192,1684238438,1667854182,1668311161,1684238386,1668512115,1685353061,1685480814,1718903152,1718907760,1919317089,1919706929,1919706930,1667786545,1667786544,1634624870,1634628454,1769173094,1819240303,1836284275,1836344951,1953330534,1953657716,1953658989,1802661484,1769175411,1936289638,1768973414,1768713314,1919706991,1919906665,1920165232,1836347494,1635149158,1635086450]
      # An instance of a IMG4 file
      class File
        attr_reader :payload, :manifest, :shasum

        def initialize(path)
          @shasum = ShaSum.from_file('/Users/rickmark/Desktop/table.txt')

          @path = path
          der = ::File.binread(path)
          @data = OpenSSL::ASN1.decode(der)
          @value = asn1_to_hash(@data)
          @type = @value.first

          case @type
          when 'IM4P'
            @type = @data.value[1].value
            @build = @data.value[2].value
            @payload = MooTool::Decompressor.new(@data.value[3].value).value
          when 'IM4M'
            @version = @value[1]
            @signature = Digest.new @value[3]
            @certificate = Certificate.new @value[4][0][0]
          when 'IMG4'
            @header = { type: @value[1][1], version: @value[1][2] }
            @value[2].each do |entry|
              case entry[0]
              when 'IM4M'
                @version = entry[1]
                @manifest = entry[2]
                @signature = Digest.new entry[3]
                @certificate = Certificate.new entry[4][0][0]
              end
            end
          else
            ap @value
            raise "Unknown IMG4 type #{@data.first}"
          end
        end

        def parse_im4m(value)
          @version = value[1]
          manifest = value[2]
          case manifest
          when 'MANB'
            payload = parse_pair manifest.value[1].value[0].value[0]
            @manifest = parse_manifest manifest.value[1]
            @signature = Digest.new @data.value[3].value
            @certificate = Models::Certificate.new @data.value[4].value

          end
        end

        def parse_manifest(manifest)
          @manp = manifest.value.first
          @elements = manifest.value.drop(1).map { |e| parse_element e.value[0] }.reduce(&:merge).transform_values do |value|
            value.map { |p| parse_element p.value[0] }.reduce(&:merge)
          end
          @elements = @elements.deep_transform_values do |element|
            case element
            when String
              if [384].include?(element.length * 8)
                Digest.new element
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
          input.value.to_a.each_slice(2).map do |key, value|
            [ key.value, value ]
          end.to_h
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
          case @type
          when 'IM4P'
            @value
          when 'IMG4'
            {
              type: @value[0],
              header: { kind: @value[1][0], type: @value[1][1], version: @value[1][2] },
              data: {
                type: @value[2][0][0],
                version: @value[2][0][1],
                manifest: @value[2][0][2][0]
              }
            }
          else
            {type: @value[0], version: @value[1], **@value[2][0]}

          end
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
              when MooTool::Digest
                value.file_names @shasum
              else
                value
              end
            end
            ap({ **output, signature: @signature, certificate: asn1_to_hash(@certificate.to_h) })
          else
            ap asn1_to_hash(@elements)
          end

        end

        private
        def asn1_to_hash(elm)
          case elm
          when nil, true, false, Time, String, Digest, Integer
            elm
          when OpenSSL::ASN1::IA5String
            elm.value
          when OpenSSL::ASN1::BitString
            Digest.new elm.value
          when OpenSSL::ASN1::OctetString
            if HASH_LENGTHS.include?(elm.value.length * 8)
              Digest.new elm.value
            else
              elm.value
            end
          when OpenSSL::ASN1::Integer
            elm.value.is_a?(OpenSSL::BN) ? elm.value.to_i : elm.value
          when OpenSSL::ASN1::ASN1Data
            case elm.tag
            when 0, 16, 17# SEQUENCE OF
              asn1_to_hash(elm.value)
            when 1,2, 5,6, 12, 31, 32,19, 33, 23, 24, 14
              elm.value
            when 22
              Digest.new elm.value
            when 3
              asn1_to_hash elm.value[0]
            else
              result = asn1_to_hash(elm.value)
              # puts elm.tag if result[0][0] == 'trst'
              case elm.tag
              when *KVP_TAGS
                if OCTET_TAGS.include?(elm.tag)
                  value = result[0][1].is_a?(Integer) ? result[0][1] : Digest.new(result[0][1])
                  { result[0][0] => value }
                else
                  { result[0][0] => result[0][1] }
                end

              when *SEQUENCE_TAGS
                { result[0][0] => result[0][1].reduce(&:merge) }
              else
                              { tag: elm.tag, value: result }
              end

            end
          when OpenSSL::ASN1::Null
            nil
          when Hash
            elm.transform_values { |value| asn1_to_hash(value) }
          when Array
            elm.map { |value| asn1_to_hash(value) }
          else
              # Primitives (Integers, OctetStrings, UTF8Strings, etc.)
              { type: elm.class.name, value: elm.value, tag: elm.tag }
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
