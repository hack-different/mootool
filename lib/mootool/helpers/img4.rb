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

      SIGNATURE_TAGS = parse_4cc(%w[])

      KEY_INSTANCE_TAGS = parse_4cc(%w[inst])

      DECODE_TAGS = parse_4cc(%w[prid])

      OCTET_TAGS = parse_4cc(%w[CHIP ECID tstp trpk cons])

      SEQUENCE_TAGS = parse_4cc(%w[MANB MANP OBJP PAYP])

      KVP_TAGS = parse_4cc(
        %w[mmap kcep kclf clas inst kclo kclz kcrf kcrz kcwf kcwz rddg tbmr tz0s drmc cons arms time UDID
           srnm auxp ksku mlb# BMac time acid WSKU Regn SrNm sei3 nuid WMac CLHS Mod# clid sip0 sip1 sip2 sip3
           smb0 auxi wmac smb1 smb2 upcl udid seid ESEC BNCH EPRO DSEC DPRO smb5 ronh AMNM trpk faic augs inst
           prid spih hrlp stng tbms vnum clas cnch fchp ndom pave styp type DGST EPRO ESEC CEPO SDOM SDOM BNCH
           EKEY CSEC CPRO BORD CHIP ECID uidm rpnh esdm apmv srvn eg0n prtp oppd sdkp snon snuf lpnh tatp tagt
           tstp love kuid vuid rolp nish lobo nsih bmac]
      )

      FIRMWARE_TAGS = parse_4cc(
        %w[lcrt scrt caos casy csos appv FSCl fCfg dCfg hop0 HmCA NvMR pcrt cphy ibd1 rtsc sePk cssy rdsk
           trca trcs anef ansf aubt aopf aupr avef bat0 bat1 batF bstc chg0 chg1 ciof stg1 csys dtre dcp2 dcpf
           isys dven ftap ftsp gfxf glyP ibdt ibec ibot ibss illb ispf ipdf rfta krnl logo msys mtfw mtpf pmcf
           pmpf rans rcio rdc2 rdcp rdtr recm rfts rkrn sptm rlg1 rlg2 rlgo bstc chg0 chg1 ciof stg1 csys dtre
           dcp2 dcpf isys dven ftap ftsp gfxf glyP ibdt ibec ibot ibss illb ispf ipdf rfta krnl logo msys mtfw
           mtpf pmcf pmpf rans rcio rdc2 rdcp rdtr recm rfts rkrn sptm rlg1 rlg2 rlgo rosi rsep tsep rspt rtmu
           rtrx sepi siof lpol trxm trst tmuf bsys]
      )

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
          MooTool::Models::IMG4::KeyValueProperty.new input
        when *SEQUENCE_TAGS
          MooTool::Models::IMG4::PropertySequence.new input
        when *FIRMWARE_TAGS
          MooTool::Models::IMG4::FirmwareEntry.new input
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
    end
  end
end
