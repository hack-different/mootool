# typed: false
# frozen_string_literal: true

require 'lzfse'
require 'lzma'
require 'compress/lzss'

module MooTool
  module Models
    # Handles decompression of Apple firmware data using various compression algorithms
    #
    # This class detects the compression format based on magic bytes (e.g., bvx2 for LZFSE)
    # and decompresses the data. It also supports parsing the decompressed data based on
    # hints (e.g., Apple-specific tags).
    class Decompressor
      include Helpers::Hashing

      # Magic for LZSS compression
      COMPRESSION_LZSS = 'lzss'
      # Magic for LZVN compression
      COMPRESSION_LZVN = 'lzvn'
      # Magic for LZFSE compression
      COMPRESSION_LZFSE = 'bvx2'
      # Magic for LZMA compression
      COMPRESSION_LZMA = 'lzma'

      # @return [String, nil] The decompressed value.
      attr_reader :value
      # @return [String] The original hash/data that was decompressed.
      attr_reader :hash
      # @return [String] The original raw data.
      attr_reader :data

      # Loads data from a file and initializes a new Decompressor
      #
      # @param filename [String] The path to the file.
      # @return [Decompressor]
      def self.load(filename)
        new File.binread(filename)
      end

      include MooTool::Helpers::IMG4

      # Initializes a new Decompressor
      #
      # @param data [String, Models::Digest] The compressed data to decompress.
      # @param hint [Symbol, String, nil] A hint for how to parse the decompressed data.
      def initialize(data, hint = nil)
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

      # Attempts to parse a public key point using various EC groups
      #
      # @param point [String] The raw point data.
      # @return [OpenSSL::PKey::EC::Point, nil] The parsed point, or nil if failed.
      def parse_point_any(point)
        %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end.compact.first
      end

      # Parses the decompressed value based on a provided hint
      #
      # @param value [String] The decompressed data.
      # @param hint [Symbol] The hint describing the data type.
      # @return [void]
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
                    when :appv, :dCfg, :fCfg
                      {
                        :type => @constructed[0].to_4cc(reverse: true),
                        :unk => @constructed[1].to_s(16),
                        Models::IMG4.key_name(:SPAY) => @constructed[2].to_h,
                        :META => @constructed[3][:META].map(&:to_h).reduce(&:merge),
                        **@constructed[4].to_h
                      }
                    when :lcrt
                      certificate = OpenSSL::ASN1.decode(@asn1.value[3].value)

                      {
                        unk1: @constructed[0],
                        unk2: @constructed[1],
                        public_key: ECCPublicKey.from_point(@asn1.value[2].value),
                        certificates: Models::Certificate.new(OpenSSL::X509::Certificate.new(certificate)),
                        unk4: @constructed[4]
                      }
                    when :scrt
                      Models::Certificate.new(OpenSSL::X509::Certificate.new(value))
                    else
                      { hint => construct(@asn1) }
                    end
        rescue StandardError => e
          @parsed = { value: Models::Digest.create(value), error: e.full_message.ai }
        end
      end

      # Returns a list of hashes for the compressed and decompressed data
      #
      # @return [Array<Hash>] List of hash entries.
      def raw_hashes
        results = [
          { kind: :'IM4P:hash', value: @hash }
        ]
        if @decompressed_hash && @decompressed_hash != @hash
          results << { kind: :'IM4P:decompressed',
                       value: @decompressed_hash }
        end
        results << { kind: :'IM4P:ASN1', value: @asn1.to_der } if @asn1

        results.compact.uniq { |entry| entry[:value] }
      end

      # Writes the original compressed data to a file
      #
      # @param path [String] The path to write to.
      # @return [void]
      def extract_to(path)
        File.binwrite(path, @data)
      end

      # Converts the decompressor state to a TreeNode structure
      #
      # @return [Helpers::TreeNode]
      def to_tree
        node = Helpers::TreeNode.new('Decompressor')

        node.children << Helpers::TreeNode.new("Length: #{@value&.size&.ai}")
        node.children << Helpers::TreeNode.new('Hash', [Helpers::TreeNode.new(to_hash(@hash))])
        node.children << Helpers::TreeNode.new("Encoding: #{@compression.ai}") if @compression

        parsed = Helpers::TreeNode.new('Parsed')

        case @parsed
        when Hash
          @parsed.map do |key, value|
            prop = Helpers::TreeNode.new(Models::IMG4.key_name(key), [Helpers::TreeNode.new(value.ai)])
            parsed.children << prop
          end
        else
          parsed.children << Helpers::TreeNode.new(@parsed.ai)
        end

        node.children << parsed
        node
      end

      # Converts the decompressor state to a Hash representation
      #
      # @return [Hash]
      def to_h
        return { value: nil } if @parsed.nil?

        result = { length: @value.size, hash: to_hash(@hash), parsed: @parsed }
        result[:compression] = @compression if @compression != :raw
        result[:decompressed_hash] = to_hash(@decompressed_hash) if @decompressed_hash && @decompressed_hash != @hash
        result[:parsed] = @parsed if @parsed
        result[:hint] = @hint if @hint
        result
      end

      # Returns a string representation for inspection
      #
      # @return [String]
      def inspect
        to_h.ai
      end
    end
  end
end
