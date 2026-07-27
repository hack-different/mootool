# frozen_string_literal: true

module MooTool
  module Models
    class Certificate
      include Helpers::IMG4

      APPLE_OID_MAP = {
        1 => :appleTrustPolicy,
        6 => {
          1 => {
            15 => :CTOidItemAppleImg4Manifest
          },
          2 => :appleSecurityAlgorithm,
          3 => :appleDotMacCertificate,
          4 => :appleExtendedKeyUsage,
          5 => :appleCertificatePolicies,

          44 => :applePinningAllowTestCertsUCRT
        },
        8 => {
          2 => :CTOidItemAppleDeviceAttestationNonce,
          4 => :CTOidItemAppleDeviceAttestationHardwareProperties,
          5 => :CTOidItemAppleDeviceAttestationKeyUsageProperties,
          7 => :CTOidItemAppleDeviceAttestationDeviceOSInformation
        }
      }.freeze

      def initialize(certificate)
        @certificate = certificate

        @extensions = certificate.extensions.map do |extension|
          parse_extension(extension)
        end.reduce(&:merge)
      end

      def oid_to_name(oid)
        return oid unless /1.2.840.113635.100/.match?(oid)

        apple_root = oid.gsub(/^1.2.840.113635.100./, '')
        oid_values = apple_root .split('.').map { |v| v.to_i }
        result = APPLE_OID_MAP.dig *oid_values
        result || apple_root
      end

      def parse_extension(extension)
        oid_name = oid_to_name(extension.oid)
        case extension.oid
        when 'basicConstraints'
          { basicConstraints: {critical: extension.critical?, constraints: extension.value } }
        when 'authorityKeyIdentifier'
          { authorityKeyIdentifier: Models::Digest.create(extension.value) }
        when 'subjectKeyIdentifier'
          { subjectKeyIdentifier: Models::Digest.create(extension.value) }
        when 'keyUsage'
          { keyUsage: { critical: extension.critical?, usage: Models::Digest.create(extension.value) } }
        when '1.2.840.113635.100.6.16','1.2.840.113635.100.6.17'
          { id: oid_name, critical: extension.critical?, value: extension.value }
        when '1.2.840.113635.100.6.1.15'
          { id: oid_name, critical: extension.critical?, value: extension.value }
        else
          { id: oid_name, critical: extension.critical?, value: extension.value }
        end
      end

      def map_to_arrays(input)
        case input
        when OpenSSL::ASN1::Set, OpenSSL::ASN1::Sequence
          input.value.map { |e| map_to_arrays(e) }
        else
          input
        end
      end

      def parse_ds_name(name)
        map_to_arrays(name).flatten.each_slice(2).to_h.transform_keys(&:to_sym)
      end

      def to_h
        { certificate: @certificate, extensions: @extensions }
      end

      def inspect
        to_h
      end
    end
  end
end
