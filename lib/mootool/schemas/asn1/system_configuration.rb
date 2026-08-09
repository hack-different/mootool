# frozen_string_literal: true

module MooTool
  module Schemas
    module ASN1
      class SystemConfiguration < RASN2::Model
        class SysConfigProperty < RASN2::Model
          sequence :SYSCONFIG_PROPERTY do
            integer(:SPAY_TAG)
            ia5_string(:SPAY_TYPE)
            choice :SPAY_VALUE do
              ia5_string(:SPAY_IA5)
              octet_string(:SPAY_OCTET)
            end
          end
        end

        class ManifestProperty < RASN2::Model
          sequence :MANIFEST_PROPERTY do
            ia5_string(:MANP_KEY)
            ia5_string(:MANP_VALUE)
          end
        end

        class ManifestInformation < RASN2::Model
          octet_string(:MANI_KEY)
        end

        sequence :SCFG do
          integer(:PAYLOAD_TYPE)
          integer(:VERSION)
          set_of(:SPAY, SysConfigProperty, class: :private, explicit: 0x53504159)
          set_of(:MANP, ManifestProperty, class: :private, explicit: 0x4D455441)
          sequence_of(:MANI, ManifestInformation, class: :private, explicit: 0x4D414E49)
        end
      end
    end
  end
end
