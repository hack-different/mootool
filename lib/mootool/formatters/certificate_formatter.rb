# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatter for MooTool::Models::Certificate objects.
    module CertificateFormatter
      # Formats a certificate object by converting it to a hash and using the default hash formatter.
      #
      # @param object [MooTool::Models::Certificate] the certificate to format
      # @return [String] the colorized string representation
      def awesome_certificate(object)
        awesome_hash(object.to_h)
      end
    end
  end
end
