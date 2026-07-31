# frozen_string_literal: true

module MooTool
  module Models
    class EncryptedPayload
      include Helpers::IMG4

      def initialize(payload)
        @data = OpenSSL::ASN1.decode(payload)
        @value = construct(@data)

        @value[1][4].hint ||= 'ECCEncryptedData'

        @algorithm = ALGORITHMS[@value[0]]
        @point = parse_point_with_match(@value[1][1])
        @nonce = @value[1][0]
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
        %w[prime256v1 secp384r1].map do |group|
          group = OpenSSL::PKey::EC::Group.new(group)
          OpenSSL::PKey::EC::Point.new(group, point)
        rescue StandardError
          nil
        end.compact.first
      end

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
