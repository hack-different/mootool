# frozen_string_literal: true

module MooTool
  module Helpers
    # Helpers that refine ASN.1 with IMG4 specific extensions and tags
    #
    # This module defines the Four-Character Codes (4CC) used by Apple in IMG4 structures
    # to identify different types of properties, firmware entries, and sequences.
    module IMG4
      extend ASN1::ClassMethods

      # Tags associated with signatures in IMG4
      SIGNATURE_TAGS = [].freeze

      # Tags associated with key instances
      KEY_INSTANCE_TAGS = parse_4cc(
        %w[inst]
      )

      # Tags that require special decoding logic
      DECODE_TAGS = parse_4cc(
        %w[prid time clid FSCl]
      )

      # Tags containing raw octet strings (often digests or IDs)
      OCTET_TAGS = parse_4cc(
        %w[CHIP ECID tstp trpk cons DPCl]
      )

      # Tags identifying property sequences
      SEQUENCE_TAGS = parse_4cc(
        %w[MANB MANP OBJP PAYP]
      )

      # Tags identifying key-value properties
      KVP_TAGS = parse_4cc(
        %w[mmap kcep kclf clas inst kclo kclz kcrf kcrz kcwf kcwz rddg tbmr tz0s drmc cons arms time UDID PAYP
           srnm auxp ksku mlb# BMac time acid WSKU Regn SrNm sei3 nuid WMac CLHS Mod# clid sip0 sip1 sip2 sip3
           smb0 auxi wmac smb1 smb2 upcl udid seid ESEC BNCH EPRO DSEC DPRO smb5 ronh AMNM trpk faic augs inst
           prid spih hrlp stng tbms vnum clas cnch fchp ndom pave styp type DGST EPRO ESEC CEPO SDOM SDOM BNCH
           EKEY CSEC CPRO BORD CHIP ECID uidm rpnh esdm apmv srvn eg0n prtp oppd sdkp snon snuf lpnh tatp tagt
           tstp love kuid vuid rolp nish lobo nsih bmac faus fsca iuos rfcg esic epse FSC2 iCCl MSRk FSCl hop0
           kcxf kcxz Coor supm]
      )

      # Tags identifying firmware entries
      FIRMWARE_TAGS = parse_4cc(
        %w[lcrt scrt caos casy csos appv FSCl fCfg dCfg hop0 HmCA NvMR pcrt cphy ibd1 rtsc sePk cssy rdsk
           trca trcs anef ansf aubt aopf aupr avef bat0 bat1 batF bstc chg0 chg1 ciof stg1 csys dtre dcp2 dcpf
           isys dven ftap ftsp gfxf glyP ibdt ibec ibot ibss illb ispf ipdf rfta krnl logo msys mtfw mtpf pmcf
           pmpf rans rcio rdc2 rdcp rdtr recm rfts rkrn sptm rlg1 rlg2 rlgo bstc chg0 chg1 ciof stg1 csys dtre
           dcp2 dcpf isys dven ftap ftsp gfxf glyP ibdt ibec ibot ibss illb ispf ipdf rfta krnl logo msys mtfw
           mtpf pmcf pmpf rans rcio rdc2 rdcp rdtr recm rfts rkrn sptm rlg1 rlg2 rlgo rosi rsep tsep rspt rtmu
           rtrx sepi siof lpol trxm trst tmuf bsys ADCL cfel hmmr pert phlt rbmt diag FSC2 iCCl MSRk]
      )

      # Mapping of IMG4 algorithm IDs to their Symbolic names
      ALGORITHMS = { 0 => :SHA1, 1 => :SHA256, 2 => :SHA384 }.freeze

      def self.included(base)
        base.include Helpers::ASN1
      end
    end
  end
end
