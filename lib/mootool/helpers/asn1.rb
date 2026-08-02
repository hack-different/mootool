# frozen_string_literal: true

require 'openssl'

module MooTool
  module Helpers
    # Helpers for parsing DER / IMG4
    module ASN1
      extend ActiveSupport::Concern

      HASH_LENGTHS = [128, 160, 224, 256, 384, 512].freeze

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

      def decode_construct(input)
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
        construct(OpenSSL::ASN1.decode(decode_target))
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
        when *self.class::KVP_TAGS
          MooTool::Models::IMG4::KeyValueProperty.new input
        when *self.class::SEQUENCE_TAGS
          MooTool::Models::IMG4::PropertySequence.new input
        when *self.class::FIRMWARE_TAGS
          MooTool::Models::IMG4::FirmwareEntry.new input
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
            { key: entry[0].to_4cc, unk: value[1], value: entry[2] }
          end
          { cc_tag => values }
        else
          { cc_tag => value }
        end
      end

      class_methods do
        def parse_4cc(input, raw_int = [])
          mapped = input.map do |value|
            value.b.unpack1('N')
          end

          raw_int + mapped
        end

        def define(name, literal_ints = [], &block)
          list_4ccs = block_given? ? block.call : []
          list_4ccs += literal_ints
          const_set name, list_4ccs.freeze
        end
      end
    end
  end
end
