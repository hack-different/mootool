# frozen_string_literal: true

module MooTool
  module Helpers
    # Helpers that refine ASN1 with IMG4 specific extensions
    module IMG4
      extend ASN1::ClassMethods

      SIGNATURE_TAGS = [].freeze

      KEY_INSTANCE_TAGS = parse_4cc(
        %w[inst]
      )

      DECODE_TAGS = parse_4cc(
        %w[prid]
      )

      OCTET_TAGS = parse_4cc(
        %w[CHIP ECID tstp trpk cons]
      )

      SEQUENCE_TAGS = parse_4cc(
        %w[MANB MANP OBJP PAYP]
      )

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
           rtrx sepi siof lpol trxm trst tmuf bsys ADCL]
      )

      ALGORITHMS = { 0 => :SHA1, 1 => :SHA256, 2 => :SHA384 }.freeze

      def self.included(base)
        base.include Helpers::ASN1
      end
    end
  end
end
