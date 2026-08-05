# typed: false
# frozen_string_literal: true

require 'lzfse'
require 'lzma'
require 'compress/lzss'

module MooTool
  module Models
    # The magic Apple decompressor (as in it uses magics)
    class Decompressor
      include Helpers::Hashing

      COMPRESSION_LZSS = 'lzss'
      COMPRESSION_LZVN = 'lzvn'
      COMPRESSION_LZFSE = 'bvx2'
      COMPRESSION_LZMA = 'lzma'

      attr_reader :value, :hash, :data

      def self.load(filename)
        new File.binread(filename)
      end

      include MooTool::Helpers::IMG4

      def initialize(data, hint)
        @hint = hint.to_sym
        data = data.value if data.is_a? MooTool::Models::Digest
        @hash = data
        @data = data
        if data == "\0" && data.size == 1
          @data = nil
          @parsed = nil
          @compression = :nil
          return
        end
        @value = case data[0..3]
                 when COMPRESSION_LZFSE
                   @compression = :lzfse
                   LZFSE.lzfse_decompress(data)
                 when COMPRESSION_LZVN
                   @compression = :lzvn
                   LZFSE.lzvn_decompress(data)
                 when COMPRESSION_LZSS
                   @compression = :lzss
                   OpenSSL::Digest::DSS.decompress(data)
                 when COMPRESSION_LZMA
                   @compression = :lzma
                   Net::DNS::QueryTypes::ATMA.decompress(data)
                 else
                   @compression = :raw
                   data
                 end

        parse_based_on_hint(@value, @hint)

        @decompressed_hash = @value
      end

      def parse_point_any(point)
        %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end.compact.first
      end

      def parse_based_on_hint(value, hint)
        @compression = :raw

        if hint == :sePk
          @compression = :ecc_point
          @parsed = parse_point_any(value)
          return
        end

        begin
          @asn1 = OpenSSL::ASN1.decode(value)
          @constructed = construct(@asn1)
          @compression = :asn1

          @parsed = case hint
                    when :scrt, :lcrt
                      certificate = OpenSSL::ASN1.decode(@asn1.value[3].value)

                      {
                        unk1: @constructed[0],
                        unk2: @constructed[1],
                        public_key: ECCPublicKey.from_point(@asn1.value[2].value),
                        certificates: Models::Certificate.new(OpenSSL::X509::Certificate.new(certificate)),
                        unk4: @constructed[4]
                      }
                    when :dCfg
                      @constructed
                    when :FSC2
                      @constructed.map do |item|
                        case item
                        when Integer
                          item.to_4cc
                        when Hash
                          item.transform_keys(&:to_4cc)
                        end
                      end
                    else
                      { hint => construct(@asn1) }
                    end
        rescue StandardError => e
          @parsed = { value: Models::Digest.create(value), error: e.full_message.ai }
        end
      end

      def raw_hashes
        results = [
          { kind: 'IM4P:hash', value: @hash }
        ]
        if @decompressed_hash && @decompressed_hash != @hash
          results << { kind: 'IM4P:decompressed',
                       value: @decompressed_hash }
        end
        results << { kind: 'IM4P:ASN1', value: @asn1.to_der } if @asn1

        results.compact.uniq { |entry| entry[:value] }
      end

      def extract_to(path)
        File.binwrite(path, @data)
      end

      def to_tree
        children = to_h.map do |key, value|
          Helpers::TreeNode.new(key, [Helpers::TreeNode.new(value.ai)])
        end

        Helpers::TreeNode.new('Decompressor', children)
      end

      def to_h
        return { value: nil } if @parsed.nil?

        result = { length: @value.size, hash: to_hash(@hash), parsed: @parsed }
        result[:compression] = @compression if @compression != :raw
        result[:decompressed_hash] = to_hash(@decompressed_hash) if @decompressed_hash && @decompressed_hash != @hash
        result[:parsed] = @parsed if @parsed
        result[:hint] = @hint if @hint
        result
      end

      def inspect
        to_h.ai
      end
    end
  end
end
