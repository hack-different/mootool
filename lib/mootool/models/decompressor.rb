# typed: false
# frozen_string_literal: true

require 'lzfse'
require 'lzma'
require 'compress/lzss'

module MooTool
  module Models
    # The magic Apple decompressor (as in it uses magics)
    class Decompressor
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
        @hash = MooTool::Models::Digest.create(::Digest::SHA384.digest(data))
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

        @decompressed_hash = MooTool::Models::Digest.create(::Digest::SHA384.digest(@value))
      end

      def parse_based_on_hint(value, hint)
        @compression = :raw
        begin
          @asn1 = OpenSSL::ASN1.decode(value)
          @constructed = construct(@asn1)
          @compression = :asn1

          @parsed = case hint
                    when :scrt, :lcrt
                      {
                        unk1: @constructed[0],
                        unk2: @constructed[1],
                        signature: Models::Digest.create(@constructed[2]),
                        certificate: OpenSSL::X509::Certificate.new(OpenSSL::ASN1.decode(@constructed[3].value).to_der),
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
                      { hint => @asn1 }
                    end
        rescue StandardError => e
          @parsed = { value: Models::Digest.create(value), error: e }
        end
      end

      def hashes
        [@hash, @decompressed_hash].compact.uniq
      end

      def inspect
        return { value: nil, hash: @hash }.ai if @parsed.nil?

        result = { length: @value.size, hash: @hash, parsed: @parsed }
        result[:compression] = @compression if @compression != :raw
        result[:decompressed_hash] = @decompressed_hash if @decompressed_hash && @decompressed_hash != @hash
        result[:parsed] = @parsed if @parsed
        result[:hint] = @hint if @hint
        result.ai
      end
    end
  end
end
