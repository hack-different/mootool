require 'set'
require 'openssl'

module MooTool
  module Helpers
    module IMG4
      def self.parse_4cc(input)
        input.map do |value|
          value.b.unpack1('N')
        end
      end

      HASH_LENGTHS = [128, 160, 224, 256, 384, 512].freeze

      OCTET_TAGS = parse_4cc(%w[prid CHIP ECID tstp trpk])
      KVP_TAGS = parse_4cc(%w[UDID trpk faic augs inst prid spih hrlp stng caos casy csos tbms vnum clas cnch fchp ndom pave styp type DGST EPRO ESEC CEPO SDOM SDOM BNCH EKEY CSEC CPRO BORD CHIP ECID uidm rpnh esdm apmv srvn eg0n prtp oppd sdkp snon snuf lpnh tatp tagt tstp love kuid vuid rolp nish lobo nsih])
      SEQUENCE_TAGS = parse_4cc(%w[MANB MANP])
      FIRMWARE_TAGS = parse_4cc(%w[cphy rtsc sePk cssy rdsk bsys trca trcs anef ansf aubt aopf aupr avef bat0 bat1 batF bstc chg0 chg1 ciof stg1 csys dtre dcp2 dcpf isys dven ftap ftsp gfxf glyP ibdt ibec ibot ibss illb ispf ipdf rfta krnl logo msys mtfw mtpf pmcf pmpf rans rcio rdc2 rdcp rdtr recm rfts rkrn sptm rlg1 rlg2 rlgo rosi rsep tsep rspt rtmu rtrx sepi siof lpol trxm trst tmuf])

      def construct_object(input)
        nil if input.nil? || input.value.nil?

        begin
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
          when OpenSSL::ASN1::EOC, OpenSSL::ASN1::SET, OpenSSL::ASN1::ENUMERATED
            input.value.map { |v| construct(v) }
          when OpenSSL::ASN1::SEQUENCE
            input.value&.map { |v| construct(v) }
          when *KVP_TAGS
            construction = construct(input.value.first)
            if OCTET_TAGS.include?(input.tag) && !construction[1].is_a?(Models::Digest)
              if construction[1].is_a?(Array)
                { construction[0].to_sym => construction[1].map { |v| Models::Digest.create(v) } }
              else
                { construction[0].to_sym => Models::Digest.new(construction[1]) }
              end
            else
              { construction[0].to_sym => construction[1] }
            end

          when *SEQUENCE_TAGS, *FIRMWARE_TAGS
            construction = construct(input.value.first)
            { construction[0].to_sym => construction[1].reduce(&:merge) }
          else
            value = case input.value
                    when Enumerable
                      input.value.map { |v| construct(v) }
                    else
                      input.value
                    end
            {tag: input.tag, other: value}
          end
        rescue => e
          raise ArgumentError, "Unable to Process: #{input.tag} - #{input.value.inspect}\n#{e.message}\n#{e.inspect}\n#{e.backtrace}\n"
        end
      end

      def construct(input)
        case input
        in OpenSSL::BN
          input.to_i
        in OpenSSL::ASN1::ASN1Data
          construct_object(input)
        in nil, true, false, String, Digest, Integer, Hash, Array
          input
        else
          raise ArgumentError, "Unable to process #{input.class} #{input.inspect}"
        end
      end
    end
  end
end
