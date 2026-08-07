# frozen_string_literal: true

module MooTool
  module Models
    # Represents a remote signing request for certificates or activation.
    # Handles parsing of complex Apple-specific signing request formats.
    class RemoteRequest
      include Helpers::IMG4

      # Regex to extract the body from a standard request wrapper.
      MATCHER_REGEX = /---------REQUEST START---------\n.*BODY: \n(?<body>.*)\n\n----------REQUEST END----------/m

      # Default elliptic curve used for parsing points.
      PRIME_CURVE = OpenSSL::PKey::EC::Group.new('prime256v1')

      # Mapping of public key property names to their expected elliptic curves.
      PUBLIC_KEY_PROPERTIES = {
        UIKPub: :prime256v1,
        RKSigningPub: :prime256v1,
        SIKPub: :secp384r1,
        RKCertificationPub: :secp384r1
      }.freeze

      # List of manifest properties that should be parsed as IMG4 files.
      MANIFEST_PROPERTIES = %i[
        Cryptex1Image4Manifest
        FWImage4Manifest
        Image4Manifest
        LocalPolicy
      ].freeze

      # Initializes a new RemoteRequest instance from parsed data.
      #
      # @param parsed_data [Hash] The decoded request data.
      def initialize(parsed_data)
        @original = parsed_data.deep_symbolize_keys
        @data = @original.dup

        @rk = {}
        handle_activation_token

        if @data.key? :RKCertification
          @rk[:certification] = parse_certification(@data[:RKCertification]).to_h
          @data.delete :RKCertification
        end

        if @data.key? :RKSignature
          @rk[:signature] = construct(OpenSSL::ASN1.decode(@data[:RKSignature]))
          @data.delete :RKSignature
        end

        handle_rk_properties

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

      # Handles extraction and parsing of Recovery Kit (RK) properties.
      #
      # @return [void]
      def handle_rk_properties
        return unless @data.key? :RKProperties

        properties = CFPropertyList.native_types(CFPropertyList::List.new(
          data: @data[:RKProperties]
        ).value).deep_symbolize_keys
        @data.delete :RKProperties
        @rk[:properties] = parse_properties properties
      end

      # Handles extraction and parsing of the activation token if present.
      #
      # @return [void]
      def handle_activation_token
        return unless @data.key? :ActivationInfoXML

        @activation_request = CFPropertyList.native_types(CFPropertyList::List.new(
          data: @data[:ActivationInfoXML]
        ).value).deep_symbolize_keys
        @activation_request[:UIKCertification][:'Ap,RemotePolicyNonceHash'] = Models::Digest.create(
          @activation_request[:UIKCertification][:'Ap,RemotePolicyNonceHash']
        )
        @activation_request[:UIKCertification][:UIKCertification] =
          parse_certification(@activation_request[:UIKCertification][:UIKCertification])
        @data.delete :ActivationInfoXML
      end

      # Parses properties within the request, converting relevant fields to richer models.
      #
      # @param properties [Hash] The properties to parse.
      # @return [Hash] The parsed properties.
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

      # Parses an ECC point and attempts to match it against known certificates.
      #
      # @param point [String] The raw ECC point data.
      # @return [Hash, OpenSSL::PKey::EC::Point] A hash containing the point and matches if found, otherwise the point.
      def parse_point_with_match(point)
        point = parse_point_any(point)
        matches = Models::CertificateIndex.current.matching_key(point)
        if matches.any?
          { key: point, matches: matches }
        else
          point
        end
      end

      # Parses an ECC point by trying known elliptic curve groups.
      #
      # @param point [String] The raw point data to parse.
      # @return [OpenSSL::PKey::EC::Point, nil] The first successfully parsed point, or nil.
      def parse_point_any(point)
        mappings = %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end

        mappings.compact.first
      end

      # Parses an ECC point for a specific curve.
      #
      # @param point [String] The raw point data.
      # @param curve [Symbol, String, OpenSSL::PKey::EC::Group] The curve to use.
      # @return [OpenSSL::PKey::EC::Point] The parsed point.
      def parse_point(point, curve = PRIME_CURVE)
        curve = OpenSSL::PKey::EC::Group.new(curve.to_s) unless curve.is_a? OpenSSL::PKey::EC::Group

        OpenSSL::PKey::EC::Point.new(curve, point)
      end

      # Parses certification data into an {EncryptedPayload}.
      #
      # @param certification [String] The raw certification data.
      # @return [EncryptedPayload] The parsed payload.
      def parse_certification(certification)
        EncryptedPayload.new(certification)
      end

      # Loads a remote request from a file.
      #
      # @param file [String] The path to the request file.
      # @return [RemoteRequest] The loaded request.
      def self.load(file)
        raw_data = File.read(file)

        body = raw_data.match(MATCHER_REGEX).named_captures['body']
        data = CFPropertyList.native_types(CFPropertyList::List.new(data: body).value)

        new(data)
      end

      # Converts the request to a hash representation.
      #
      # @return [Hash] A hash containing activation request and recovery kit information.
      def to_h
        result = {}
        result[:activation_request] = @activation_request if @activation_request
        result[:recovery_kit] = @rk if @rk
      end

      # Returns a string representation of the request for debugging.
      #
      # @return [String] The inspected hash.
      def inspect
        to_h.ai
      end
    end
  end
end
