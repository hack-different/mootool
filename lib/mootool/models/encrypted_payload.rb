# frozen_string_literal: true

module MooTool
  module Models
    # Represents an encrypted payload, typically used in IMG4 containers.
    class EncryptedPayload
      include Helpers::IMG4

      # Initializes a new EncryptedPayload instance.
      #
      # @param payload [String] The raw ASN1 encoded payload data.
      def initialize(payload)
        @data = OpenSSL::ASN1.decode(payload)
        @value = construct(@data)

        @value[1][4].hint ||= 'ECCEncryptedData'

        @algorithm = ALGORITHMS[@value[0]]
        @point = parse_point_with_match(@value[1][1])
        @nonce = @value[1][0]
      end

      # Parses an ECC point and attempts to match it against known certificates.
      #
      # @param point [String] The raw ECC point data.
      # @return [Hash, OpenSSL::PKey::EC::Point] A hash containing the point and matches if any are found, otherwise just the point.
      def parse_point_with_match(point)
        point = parse_point_any(point)
        matches = Models::CertificateIndex.current.matching_key(point)
        if matches.any?
          { key: point.to_h, matches: matches }
        else
          point
        end
      end

      # Parses an ECC point by trying known elliptic curve groups.
      #
      # @param point [String] The raw point data to parse.
      # @return [OpenSSL::PKey::EC::Point, nil] The first successfully parsed point, or nil.
      def parse_point_any(point)
        %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end.compact.first
      end

      # Converts the encrypted payload to a hash representation.
      #
      # @return [Hash] A hash containing HMAC function, IVs, ECIES information, and encrypted data.
      def to_h
        {
          hmac_function: @algorithm,
          ecies_iv: Models::Digest.create(@value[1][2].raw, 'IV AES128'),
          data_iv: Models::Digest.create(@value[1][3].raw, 'IV AES128'),
          ecies: Models::ECIESEncryption.new(@point, @nonce),
          encrypted_data: @value[1][4]
        }
      end
    end
  end
end
