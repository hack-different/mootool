class MooTool::Schemas::ASN1::SystemConfiguration < RASN2::Model
  class SysConfigProperty < RASN2::Model
    sequence :SYSCONFIG_PROPERTY, content: [
      integer(:SPAY_TAG),
      ia5_string(:SPAY_FILTER),
      choice(:SPAY_VALUE, content: [
        ia5_string(:SPAY_IA5),
        octet_string(:SPAY_OCTET)
      ])

    ]
  end

  class ManifestProperty < RASN2::Model
    sequence :MANIFEST_PROPERTY, content: [
      ia5_string(:MANP_KEY),
      ia5_string(:MANP_VALUE)
    ]
  end

  class ManifestInformation < RASN2::Model
    octet_string(:MANI_KEY)
  end

  sequence :SCFG, content: [
    integer(:PAYLOAD_TYPE),
    integer(:VERSION),
    set_of(:SPAY, SysConfigProperty, class: :private, explicit: 0x53504159),
    set_of(:MANP, ManifestProperty, class: :private, explicit: 0x4D455441),
    sequence_of(:MANI, ManifestInformation, class: :private, explicit: 0x4D414E49)
  ]
end