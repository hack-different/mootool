# frozen_string_literal: true

module MooTool
  module Models
    class RemoteRequest
      include Helpers::IMG4

      MATCHER_REGEX = /---------REQUEST START---------\n.*BODY: \n(?<body>.*)\n\n----------REQUEST END----------/m

      PRIME_CURVE = OpenSSL::PKey::EC::Group.new('prime256v1')

      ALGORITHMS = { 0 => :SHA1, 1 => :SHA256, 2 => :SHA384 }.freeze

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
          @rk[:certification] = parse_certification(@data[:RKCertification]).to_h
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
          @rk[:signing_pub] = parse_point_with_match(@data[:RKSigningPub])
          @data.delete :RKSigningPub
        end

        if @data.key? :RKPropertiesSignature
          @rk[:properties_signature] = Models::ECCSignature.create(@data[:RKPropertiesSignature])
          @data.delete :RKPropertiesSignature
        end

        return unless @data.key? :RKSigning

        @rk[:signing] = parse_certification(@data[:RKSigning]).to_h
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

        PUBLIC_KEY_PROPERTIES.each_key do |prop|
          next unless properties.key? prop

          properties[prop] = parse_point_with_match(properties[prop])
        end

        properties
      end

      def parse_point_with_match(point)
        point = parse_point_any(point)
        matches = Models::CertificateIndex.current.matching_key(point)
        if matches.any?
          { key: point, matches: matches }
        else
          point
        end
      end

      def parse_point_any(point)
        mappings = %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end

        mappings.compact.first
      end

      def parse_point(point, curve = PRIME_CURVE)
        curve = OpenSSL::PKey::EC::Group.new(curve.to_s) unless curve.is_a? OpenSSL::PKey::EC::Group

        OpenSSL::PKey::EC::Point.new(curve, point)
      end

      def parse_certification(certification)
        EncryptedPayload.new(certification)
      end

      def self.load(file)
        raw_data = File.read(file)

        body = raw_data.match(MATCHER_REGEX).named_captures['body']
        data = CFPropertyList.native_types(CFPropertyList::List.new(data: body).value)

        new(data)
      end

      def to_h
        result = {}
        result[:activation_request] = @activation_request if @activation_request
        result[:recovery_kit] = @rk if @rk
      end

      def inspect
        to_h.ai
      end
    end
  end
end
