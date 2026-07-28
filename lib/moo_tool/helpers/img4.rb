# frozen_string_literal: true

require 'openssl'

module MooTool
  module Helpers
    module IMG4
      def self.parse_4cc(input, raw_int = [])
        mapped = input.map do |value|
          value.b.unpack1('N')
        end

        raw_int + mapped
      end

      HASH_LENGTHS = [128, 160, 224, 256, 384, 512].freeze

      OCTET_TAGS = parse_4cc(%w[prid CHIP ECID tstp trpk])
      KVP_TAGS = parse_4cc(
        %w[UDID bmac srnm auxp sip0 sip1 sip2 sip3 smb0 auxi wmac smb1 smb2 upcl udid seid ESEC BNCH EPRO DSEC DPRO smb5 ronh AMNM trpk faic augs inst prid spih hrlp stng caos casy csos tbms vnum clas
           cnch fchp ndom pave styp type DGST EPRO ESEC CEPO SDOM SDOM BNCH EKEY CSEC CPRO BORD CHIP ECID uidm rpnh esdm apmv srvn eg0n prtp oppd sdkp snon snuf lpnh tatp tagt tstp love kuid vuid rolp nish lobo nsih], []
      )
      SEQUENCE_TAGS = parse_4cc(%w[MANB MANP OBJP])
      FIRMWARE_TAGS = parse_4cc(%w[cphy rtsc sePk cssy rdsk bsys trca trcs anef ansf aubt aopf aupr avef bat0 bat1 batF
                                   bstc chg0 chg1 ciof stg1 csys dtre dcp2 dcpf isys dven ftap ftsp gfxf glyP ibdt ibec ibot ibss illb ispf ipdf rfta krnl logo msys mtfw mtpf pmcf pmpf rans rcio rdc2 rdcp rdtr recm rfts rkrn sptm rlg1 rlg2 rlgo rosi rsep tsep rspt rtmu rtrx sepi siof lpol trxm trst tmuf])

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
          case input.value
          when Array
            input.value.map { |v| construct(v) }
          when String
            Models::Digest.create input.value
          else
            input.value
          end
        when OpenSSL::ASN1::OCTET_STRING
          if HASH_LENGTHS.include?(input.value.size * 8) || (input.value.size * 8) > 1024
            Models::Digest.create input.value
          else
            input.value
          end
        when *KVP_TAGS
          KeyValueProperty.new input
        when *SEQUENCE_TAGS, *FIRMWARE_TAGS
          PropertySequence.new input
        when OpenSSL::ASN1::EOC, OpenSSL::ASN1::SET, OpenSSL::ASN1::ENUMERATED
          input.value.map { |v| construct(v) }
        when OpenSSL::ASN1::SEQUENCE
          input.value&.map { |v| construct(v) }
        else
          value = case input.value
                  when Enumerable
                    input.value.map { |v| construct(v) }
                  else
                    construct(input.value)
                  end

          { input.tag => value }

        end
      end

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
    end

    class PropertySequence
      include Helpers::IMG4

      attr_reader :value, :key, :values

      def initialize(input)
        construction = construct(input.value.first)
        @key = construction[0].to_sym
        value = construction[1]
        case value
        when Array, Hash
          @value = value
        when PropertySequence
          @value = { value.key => value.value }
        end

        return unless @value.is_a?(Array)

        @value = @value.map(&:to_h).reduce({}, :merge)
      end

      def to_h
        { @key => @value }
      end

      def inspect
        to_h.ai
      end
    end

    class KeyValueProperty
      include Helpers::IMG4

      attr_reader :key, :value, :object

      SPLAT_SENINEL = :ALLOW_ANY_VALUE

      def initialize(input)
        unless input.tag_class == :PRIVATE && input.is_a?(OpenSSL::ASN1::ASN1Data)
          raise 'Input must be a private instance of ASN1Data'
        end

        @object = input

        construction = construct(input.value.first)

        @key = construction.first.to_sym
        @value = construction.last

        @value = @value.first if @value.is_a?(Array)

        @value = SPLAT_SENINEL if @value.nil?
        @value = nil if @value.is_a?(OpenSSL::ASN1::ASN1Data) && @value.value.nil?
        # @value = SPLAT_SENINEL if @value.is_a?(OpenSSL::ASN1::ASN1Data) && @value.value == nil

        return unless OCTET_TAGS.include?(input.tag) && !@value.is_a?(Models::Digest) && @value != SPLAT_SENINEL

        @value = Models::Digest.create(@value)
      end

      def to_h
        { @key => @value }
      end

      def inspect
        to_h.ai
      end
    end
  end
end
