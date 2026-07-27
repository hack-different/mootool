# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    class Certificate
      include Helpers::IMG4

      IMG4_EXTENSIONS = [
        :appleImg4Manifest,
      ].freeze

      SEQUENCE_EXTENSIONS = [
        :appleDeviceAttestationDeviceOSInformation
      ].freeze

      SCALAR_EXTENSIONS = [
        :appleUniqueDeviceCertificate
      ]

      HASH_EXTENSIONS = [
        :appleUniqueDeviceCertificateHardwareProperties
      ]

      APPLE_OID_MAP = {
        1 => :appleTrustPolicy,
        6 => {
          1 => {
            15 => :appleImg4Manifest
          },
          2 => :appleSecurityAlgorithm,
          3 => :appleDotMacCertificate,
          4 => :appleExtendedKeyUsage,
          5 => :appleCertificatePolicies,

          44 => :applePinningAllowTestCertsUCRT
        },
        8 => {
          2 => :appleDeviceAttestationNonce,
          4 => :appleDeviceAttestationHardwareProperties,
          5 => :appleDeviceAttestationKeyUsageProperties,
          7 => :appleDeviceAttestationDeviceOSInformation
        },
        10 => {
          1 => :appleUniqueDeviceCertificateHardwareProperties,
          2 => :appleUniqueDeviceCertificate
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
        oid_values = apple_root.split('.').map(&:to_i)
        result = APPLE_OID_MAP.dig(*oid_values)
        result || apple_root
      end

      def parse_extension(extension)
        oid_name = oid_to_name(extension.oid)
        value = case extension.oid
                when 'basicConstraints'
                  extension.value
                when 'authorityKeyIdentifier', 'subjectKeyIdentifier', 'keyUsage'
                  Models::Digest.create(extension.value)
                else
                  if IMG4_EXTENSIONS.include?(oid_name)
                    IMG4::File.new(extension.value_der).to_h
                  elsif SCALAR_EXTENSIONS.include?(oid_name)
                    construct(OpenSSL::ASN1.decode(extension.value_der)).first
                  elsif HASH_EXTENSIONS.include?(oid_name)
                    construct(OpenSSL::ASN1.decode(extension.value_der)).map{|p| p.to_h }.reduce(&:merge)
                  elsif SEQUENCE_EXTENSIONS.include? oid_name
                    resequence(construct(OpenSSL::ASN1.decode(extension.value_der)))
                  else
                    construct(OpenSSL::ASN1.decode(extension.value_der))
                  end
                end

        { oid_name.to_sym => { critical: extension.critical?, value: value } }
      end

      def resequence(input)
        result = input.reduce(&:merge).transform_values(&:first)
        result.is_a?(Array) ? result.reduce(&:merge) : result
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
