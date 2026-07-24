module MooTool
  module Models
    class Certificate
      def initialize(sequence)
        @certificate = sequence


        @decoded = {
          version: @certificate[0][0],
          serial_number: @certificate[1],
          algorithm: { @certificate[2][0].to_sym => @certificate[2][1] },
          issuer: parse_ds_name(@certificate[3]),
          validity: {
            not_before: @certificate[4][0],
            not_after: @certificate[4][1],
          },
          subject: parse_ds_name(@certificate[5]),
          key: {
            @certificate[6][0][0].to_sym =>
              @certificate[6][0][1],
            :data => @certificate[6][1]
          },
          extensions: @certificate[7]
        }
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
        map_to_arrays(name).flatten.each_slice(2).to_h.transform_keys do |key|
          key.to_sym
        end
      end

      def to_h
        @decoded
      end
    end
  end
end