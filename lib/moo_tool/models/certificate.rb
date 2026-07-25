# frozen_string_literal: true

module MooTool
  module Models
    class Certificate
      include Helpers::IMG4

      def initialize(sequence)
        @certificate = sequence

        @decoded = {
          version: @certificate[0][0],
          serial_number: @certificate[1],
          algorithm: { @certificate[2][0].to_sym => @certificate[2][1] },
          issuer: parse_ds_name(@certificate[3]),
          validity: {
            not_before: @certificate[4][0],
            not_after: @certificate[4][1]
          },
          subject: parse_ds_name(@certificate[5]),
          key: {
            @certificate[6][0][0].to_sym =>
              @certificate[6][0][1],
            :public_key => @certificate[6][1]
          },
          extensions: @certificate[7][0].map { |e| parse_extension(e) }
        }
      end

      def parse_extension(extension)
        case extension[0]
        when 'basicConstraints'
          { basicConstraints: {critical: extension[1], constraints: @certificate[2][0] } }
        when 'authorityKeyIdentifier'
          { authorityKeyIdentifier: Digest.create(extension[1]) }
        when 'subjectKeyIdentifier'
          { subjectKeyIdentifier: Digest.create(extension[1]) }
        when 'keyUsage'
          { keyUsage: { critical: extension[1], usage: Digest.create(extension[2]) } }
        when '1.2.840.113635.100.6.1.15', '1.2.840.113635.100.6.16','1.2.840.113635.100.6.17'
          if extension[1].is_a?(String)
            { extension[0] => construct(OpenSSL::ASN1.decode(extension[1])) }
          else
            { extension[0] => { value: construct(OpenSSL::ASN1.decode(extension[2].to_s)), critical: extension[1] } }
          end
        else
          extension
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
        @decoded
      end

      def inspect
        @decoded.to_h
      end
    end
  end
end
