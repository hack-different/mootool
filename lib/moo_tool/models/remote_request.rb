# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    class RemoteRequest
      include Helpers::IMG4

      MATCHER_REGEX = /---------REQUEST START---------\n.*BODY: \n(?<body>.*)\n\n----------REQUEST END----------/m

      MANIFEST_PROPERTIES = %i[
        Cryptex1Image4Manifest
        FWImage4Manifest
        Image4Manifest
        LocalPolicy
      ].freeze

      def initialize(parsed_data)
        @original = parsed_data.deep_symbolize_keys
        @data = @original.dup

        @rk = {}
        if @data.key? :ActivationInfoXML
          @activation_request = CFPropertyList.native_types(CFPropertyList::List.new(data: @data[:ActivationInfoXML]).value).deep_symbolize_keys
          @activation_request[:UIKCertification][:'Ap,RemotePolicyNonceHash'] = Models::Digest.create(@activation_request[:UIKCertification][:'Ap,RemotePolicyNonceHash'])
          @activation_request[:UIKCertification][:UIKCertification] =
            parse_certification(@activation_request[:UIKCertification][:UIKCertification])
          @data.delete :ActivationInfoXML
        end

        if @data.key? :RKCertification
          @rk[:certification] = parse_certification(@data[:RKCertification])
          @data.delete :RKCertification
        end
        @rk[:signature] = Models::Digest.create(@data[:RKSignature])

        if @data.key? :RKProperties
          properties = CFPropertyList.native_types(CFPropertyList::List.new(data: @data[:RKProperties]).value).deep_symbolize_keys
          @data.delete :RKProperties
          @rk[:properties] = parse_properties properties
        end

        if @data.key? :RKSigningPub
          @rk[:signing_pub] = Models::Digest.create(@data[:RKSigningPub])
          @data.delete :RKSigningPub
        end

        if @data.key? :RKPropertiesSignature
          @rk[:properties_signature] = Models::Digest.create(@data[:RKPropertiesSignature])
          @data.delete :RKPropertiesSignature
        end

        return unless @data.key? :RKSigning

        @rk[:signing] = @data[:RKSigning]
        @data.delete :RKSigning
      end

      def parse_properties(properties)
        MANIFEST_PROPERTIES.each do |prop|
          next unless properties.key? prop

          properties[prop] = IMG4::File.new(properties[prop]).to_h
        end

        if properties.key? :OIDSToInclude
          properties[:OIDSToInclude] = properties[:OIDSToInclude].map { |oid| Certificate.oid_to_name(oid) }
        end

        properties
      end

      def parse_certification(certification)
        # certification[:"Ap,RemotePolicyNonceHash"] = Models::Digest.create(certification[:"Ap,RemotePolicyNonceHash"])
        construct OpenSSL::ASN1.decode(certification)
      end

      def self.load(file)
        raw_data = File.read(file)

        body = raw_data.match(MATCHER_REGEX).named_captures['body']
        data = CFPropertyList.native_types(CFPropertyList::List.new(data: body).value)

        new(data)
      end

      def to_h
        { data: @data, activation_request: @activation_request, rk: @rk }
      end

      def inspect
        to_h.ai
      end
    end
  end
end
