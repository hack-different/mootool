# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    class RemoteRequest
      include Helpers::IMG4

      MATCHER_REGEX = /---------REQUEST START---------\n.*BODY: \n(?<body>.*)\n\n----------REQUEST END----------/m

      PRIME_CURVE = OpenSSL::PKey::EC::Group.new('prime256v1')

      ALGORITHMS = { 0 => :RSA, 1 => :ECC_MQV, 2 => :ECC_HMQV }.freeze

      PUBLIC_KEY_PROPERTIES = {
        UIKPub: :prime256v1,
        RKSigningPub: :prime256v1,
        SIKPub: :secp384r1,
        RKCertificationPub: :secp384r1
      }.freeze

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

        if @data.key? :RKSignature
          @rk[:signature] = construct(OpenSSL::ASN1.decode(@data[:RKSignature]))
          @data.delete :RKSignature
        end

        if @data.key? :RKProperties
          properties = CFPropertyList.native_types(CFPropertyList::List.new(data: @data[:RKProperties]).value).deep_symbolize_keys
          @data.delete :RKProperties
          @rk[:properties] = parse_properties properties
        end

        if @data.key? :RKSigningPub
          @rk[:signing_pub] = parse_point(@data[:RKSigningPub])
          @data.delete :RKSigningPub
        end

        if @data.key? :RKPropertiesSignature
          @rk[:properties_signature] = Certificate::ECCSignature.create(@data[:RKPropertiesSignature])
          @data.delete :RKPropertiesSignature
        end

        return unless @data.key? :RKSigning

        @rk[:signing] = parse_certification(@data[:RKSigning])
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

        PUBLIC_KEY_PROPERTIES.each do |prop, curve|
          next unless properties.key? prop

          properties[prop] = parse_point_any(properties[prop])
        end

        properties
      end

      def parse_point_any(point)
        mappings = ['prime256v1', 'secp384r1'].map do |group|
          begin
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
          rescue
              nil
          end
        end

        mappings.compact.first
      end

      def parse_point(point, curve = PRIME_CURVE)
        curve = OpenSSL::PKey::EC::Group.new(curve.to_s) unless curve.is_a? OpenSSL::PKey::EC::Group

        OpenSSL::PKey::EC::Point.new(curve, point)
      end

      def parse_certification(certification)
        # certification[:"Ap,RemotePolicyNonceHash"] = Models::Digest.create(certification[:"Ap,RemotePolicyNonceHash"])

        data = construct OpenSSL::ASN1.decode(certification)

        data[1][4].hint ||= 'ECCEncryptedData'

        {
          algorithm: ALGORITHMS[data[0]],
          signature: {
            nonce: data[1][0],
            ecc_point: parse_point(data[1][1]),
            vuid: data[1][2],
            kuid: data[1][3],
            encrypted_data: data[1][4]
          }
        }
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
