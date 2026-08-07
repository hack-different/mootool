# frozen_string_literal: true

require 'openssl'

module MooTool
  # Helper modules for MooTool
  module Helpers
    # Helpers for parsing DER / IMG4 formatted ASN.1 data
    #
    # This module provides utilities for constructing Ruby objects from ASN.1 structures,
    # specifically tailored for Apple's IMG4 and related formats.
    module ASN1
      extend ActiveSupport::Concern

      # List of common hash bit-lengths used in Apple ASN.1 structures
      HASH_LENGTHS = [128, 160, 224, 256, 384, 512].freeze

      # Recursively constructs Ruby objects from OpenSSL ASN.1 objects
      #
      # @param input [OpenSSL::ASN1::ASN1Data, OpenSSL::BN, nil, true, false, String, Models::Digest, Integer, Hash, Array]
      #   The ASN.1 object or raw value to convert.
      # @return [Object, nil] The converted Ruby object (Integer, String, Array, Hash, etc.)
      def construct(input)
        case input
        when OpenSSL::ASN1::Null
          nil
        when OpenSSL::BN
          input.to_i
        when nil, true, false, String, Models::Digest, Integer, Hash, Array
          input
        else
          construct_object(input)
        end
      end

      # Decodes a DER-encoded ASN.1 structure and constructs it into Ruby objects
      #
      # @param input [MooTool::Models::Digest, OpenSSL::ASN1::OctetString, UUIDTools::UUID, String, nil]
      #   The encoded data to decode.
      # @param tag [Symbol, nil] Optional tag to specify special decoding logic (e.g., :clid, :prid)
      # @return [Object, nil] The decoded and constructed Ruby object.
      # @raise [ArgumentError] If a special tag is provided but the structure is invalid.
      #
      # @example Decoding a PRID structure
      #   decode_construct(der_data, :prid)
      def decode_construct(input, tag = nil)
        decode_target = case input
                        when MooTool::Models::Digest, OpenSSL::ASN1::OctetString
                          input.value
                        when UUIDTools::UUID
                          input.raw
                        when nil
                          return nil
                        else
                          input
                        end
        result = construct(OpenSSL::ASN1.decode(decode_target))

        case tag
        when :clid
          Models::Digest.from_hex construct(OpenSSL::ASN1.decode(result))
        when :prid
          case result&.size
          when 3
            {
              scheme: :ecies_ecdh,
              ecc_r: result[0],
              hmac_e: result[1],
              hmac_m: result[2]
            }
          when 4
            {
              scheme: :ecies_ecdhe,
              ecc_r: result[0],
              hmac_e: result[1],
              hmac_r: result[2],
              ephemeral_r: result[3]
            }
          else
            raise ArgumentError, 'Invalid PRID ASN1 object'
          end
        else
          result
        end
      end

      private

      def construct_bitstring(input)
        case input.value
        when Array
          input.value.map { |v| construct(v) }
        when String
          Models::Digest.create input.value
        else
          input.value
        end
      end

      def construct_object(input)
        nil if input.nil? || input.value.nil?

        case input.tag
        when OpenSSL::ASN1::NULL
          nil
        when OpenSSL::ASN1::INTEGER
          construct(input.value)
        when OpenSSL::ASN1::BOOLEAN, OpenSSL::ASN1::UTCTIME, OpenSSL::ASN1::GENERALIZEDTIME,
          OpenSSL::ASN1::UTF8STRING, OpenSSL::ASN1::IA5STRING, OpenSSL::ASN1::OBJECT

          input.value
        when OpenSSL::ASN1::BIT_STRING
          construct_bitstring(input)
        when OpenSSL::ASN1::OCTET_STRING
          construct_octet_string(input)
        when *self.class::SEQUENCE_TAGS
          MooTool::Models::IMG4::PropertySequence.new input
        when *self.class::FIRMWARE_TAGS
          MooTool::Models::IMG4::FirmwareEntry.new input
        when *self.class::KVP_TAGS
          MooTool::Models::IMG4::KeyValueProperty.new input
        when OpenSSL::ASN1::EOC, OpenSSL::ASN1::SET, OpenSSL::ASN1::ENUMERATED, OpenSSL::ASN1::SEQUENCE
          input.value&.map { |v| construct(v) }
        else
          construct_other(input)
        end
      end

      def construct_octet_string(input)
        if HASH_LENGTHS.include?(input.value.size * 8) || (input.value.size * 8) > 1024
          Models::Digest.create input.value
        else
          input.value
        end
      end

      def construct_other(input)
        value = case input.value
                when Enumerable
                  input.value.map { |v| construct(v) }
                else
                  construct(input.value)
                end

        cc_tag = input.tag.to_4cc
        case cc_tag
        when :SPAY
          values = value[0].map do |entry|
            Models::IMG4::SysCfgEntry.new(entry)
          end
          Models::IMG4::SysCfgPayload.new values
        else
          { cc_tag => value }
        end
      end

      class_methods do
        # Parses a list of strings into their 4CC (Four-Character Code) integer representations
        #
        # @param input [Array<String>] List of 4-character strings.
        # @param raw_int [Array<Integer>] Optional list of existing integers to prepend.
        # @return [Array<Integer>] The combined list of 4CC integers.
        def parse_4cc(input, raw_int = [])
          mapped = input.map do |value|
            value.b.unpack1('N')
          end

          raw_int + mapped
        end

        # Defines a constant containing a list of 4CC integers
        #
        # @param name [Symbol, String] The name of the constant to define.
        # @param literal_ints [Array<Integer>] A list of literal integers to include.
        # @yieldreturn [Array<Integer>] An optional block returning more integers.
        # @return [Array<Integer>] The final list of integers assigned to the constant.
        def define(name, literal_ints = [], &block)
          list_4ccs = block_given? ? block.call : []
          list_4ccs += literal_ints
          const_set name, list_4ccs.freeze
        end
      end
    end
  end
end
