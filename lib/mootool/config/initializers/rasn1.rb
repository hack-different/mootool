# frozen_string_literal: true

module RASN2
  module Types
    class PrintableString
      def check_characters
        m = @value.to_s.match(%r{([^a-zA-Z0-9 '=()+,\-./_:?])})
        raise ASN1Error, "PRINTABLE STRING #{@name}: invalid character: '#{m[1]}'" if m
      end
    end
  end
end
