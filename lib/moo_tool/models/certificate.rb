# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    class Certificate
      include Helpers::IMG4

      def self.load_oid_map(path)
        YAML.load_file(path).deep_symbolize_keys
      end

      APPLE_OID_MAP = load_oid_map('/Users/rickmark/Sites/apple-knowledge/_data/pki.yaml')

      def initialize(certificate)
        @certificate = certificate

        @extensions = certificate.extensions.map do |extension|
          parse_extension(extension)
        end.reduce(&:merge)
      end

      def self.oid_properties(oid)
        match = APPLE_OID_MAP.dig :oids, oid.to_sym

        match ||= { name: oid.to_sym }
        match[:name] = (match[:name] || oid).to_sym
        match[:type] = match[:type].to_sym if match[:type]
        match
      end

      def self.oid_to_name(oid)
        oid = oid.to_sym
        result = APPLE_OID_MAP.dig(:oids, oid, :name) || oid
        result.to_sym
      end

      def parse_extension(extension)
        oid_properties = Certificate.oid_properties(extension.oid)
        value = case oid_properties[:name]
                when :basicConstraints
                  extension.value
                when :keyUsage
                  construct(OpenSSL::ASN1.decode(extension.value_der))
                when :authorityKeyIdentifier, :subjectKeyIdentifier
                  extension.value
                else
                  case oid_properties[:type]
                  when :img4
                    IMG4::File.new(extension.value_der).to_h
                  when :scalar
                    construct(OpenSSL::ASN1.decode(extension.value_der)).first
                  when :hash
                    construct(OpenSSL::ASN1.decode(extension.value_der)).map(&:to_h).reduce(&:merge)
                  when :sequence
                    resequence(construct(OpenSSL::ASN1.decode(extension.value_der)))
                  else
                    construct(OpenSSL::ASN1.decode(extension.value_der))
                  end
                end

        if extension.critical?
          { oid_properties[:name].to_sym => { critical: extension.critical?, value: value } }
        else
          { oid_properties[:name].to_sym => value }
        end
      end

      def resequence(input)
        input.map(&:to_h).reduce(&:merge)
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
