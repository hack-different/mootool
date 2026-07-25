require 'set'

module MooTool
  module Helpers
    module IMG4
      def self.parse_4cc(input)
        input.map do |value|
          value.b.unpack1('N')
        end
      end

      HASH_LENGTHS = [160, 224, 256, 384, 512].freeze

      KVP_TAGS = parse_4cc(%w[faic inst eg0n oppd DGST ESEC EPRO BNCH tbms apmv esdm prid srvn tstp prtp sdkp snon tagt uidm tatp spih hrlp vnum stng clas pave snuf EKEY UDID fchp augs cnch upcl ndom styp type kuid lpnh love rpnh rolp vuid nish nsih lobo ECID CEPO SDOM CSEC CPRO CHIP BORD])
      SEQUENCE_TAGS = parse_4cc(%w[sePk csos caos cssy trca casy trcs])
      FIRMWARE_TAGS = parse_4cc(%w[ MANP rspt aubt avef bat0 rlg1 rlg2 rlgo rosi rsep rspt recm rcio rans aupr bstc chg1 sepi rtmu rtrx ipdf illb mtfw trxm siof ftap dven anef ansf aopf bat1 batF ftsp gfxf sptm chg0 ciof csys dcp2 dcpf dtre ibot ibec ibdt glyP ibss tmuf logo krnl isys ispf stg1 msys cphy pmpf pmcf mtpf rdtr rdcp rdc2 rfta rfts rkrn trst])

      def construct_object(input)
        begin
          case input.tag
          when OpenSSL::ASN1::SEQUENCE, OpenSSL::ASN1::SET
            input.value.map { |v| construct(v) }
          when *KVP_TAGS
            construction = construct(input.value).first
            { construction[0] => construction[1] }
          when *SEQUENCE_TAGS
            construction = construct(input.value).first
            values = construction[1] ? construction[1].reduce({}, :merge) : {}
            { construction[0] => values }
          when *FIRMWARE_TAGS
            construction = construct(input.value).first
            values = construction[1] ? construction[1].reduce({}, :merge) : {}
            { construction[0] => values }
          else
            construct(input.value).first
          end
        rescue => e
          ap input.value
          raise ArgumentError, "Unable to Process: #{input}\n#{e.inspect}"
        end
      end

      def construct(input)
        case input
        when OpenSSL::ASN1::Boolean, OpenSSL::ASN1::PrintableString, OpenSSL::ASN1::UTF8String,
          OpenSSL::ASN1::UniversalString, OpenSSL::ASN1::Null, OpenSSL::ASN1::UTCTime, OpenSSL::ASN1::IA5String,
          OpenSSL::ASN1::ObjectId

          input.value
        when OpenSSL::ASN1::OctetString, OpenSSL::ASN1::BitString
          Digest.new input.value
        when OpenSSL::ASN1::Integer
          input.value.to_i
        when OpenSSL::BN
          input.to_i
        when OpenSSL::ASN1::Sequence, OpenSSL::ASN1::Enumerated, OpenSSL::ASN1::Set
          construct_object(input)
        when OpenSSL::ASN1::ASN1Data
          construct_object(input)
        when String, Digest, NilClass
          input
        when Array
          input.map do |value|
            construct(value)
          end
        else
          raise ArgumentError, "Unable to process #{input.class} #{input.inspect}"
        end
      end
    end
  end
end
