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

      DECODE_TAGS = parse_4cc(%w[clid])
      OCTET_TAGS = parse_4cc(%w[tbms vuid kuid prid])
      KVP_TAGS = parse_4cc(%w[faic vnum trcs inst eg0n oppd DGST ESEC EPRO BNCH tbms apmv esdm prid srvn tstp prtp sdkp snon tagt uidm tatp spih hrlp vnum stng clas pave trcs snuf EKEY UDID fchp augs cnch upcl ndom styp type kuid lpnh love rpnh rolp vuid nish nsih lobo ECID CEPO SDOM CSEC CPRO CHIP BORD])
      SEQUENCE_TAGS = parse_4cc(%w[OBJP MANP dCfg casy caos csos cssy aupr ansf aubt anef aopf csys bstc avef batF bat0 bat1 ciof cphy chg1 chg0 dven dcpf dcp2 dtre MANB lcrt gfxf ftsp ftap illb lpol ibss glyP ibot ipdf ibdt ibec ispf isys trca krnl mtfw msys logo rans mtpf pmcf pmpf recm rcio rdc2 rdsk rdcp rdtr trxm rfta rkrn trst rfts tmuf stg1 rlg1 rlg2 rsep rlgo rosi rspt sptm siof sepi rtsc rtmu rtrx])

      # An instance of a IMG4 file
      class File
        attr_reader :payload, :manifest, :shasum

        include Helpers::IMG4

        def self.load(path)
          data = ::File.binread(path)
          File.new(data)
        end

        def initialize(der)
          @shasum = ShaSum.from_file('/Users/rickmark/Desktop/table.txt')

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
              signature: Digest.create(@value[3]),
              certificate: Certificate.new(@value[4][0][0])
            }
          when 'IMG4'
            @value[2].each do |entry|
              case entry[0]
              when 'IM4M'
                @content[:im4m] = {
                  version: entry[1],
                  MANB: entry[2][0],
                  signature: Digest.create(entry[3]),
                  certificate: Certificate.new(entry[4][0][0]),
                }
              when 'IM4P'
                @content[:im4p] = {
                  im4p_type: entry[1],
                  version: entry[2],
                  manifest: entry[3],
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
            ap output
          else
            ap asn1_to_hash(@elements)
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
