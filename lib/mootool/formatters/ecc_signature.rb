# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatter for ECC signature objects.
    module ECCSignature
      # Formats an ECC signature by displaying its r and s components.
      #
      # @param signature [MooTool::Models::ECCSignature] the signature to format
      # @return [String] the colorized string representation
      def awesome_ecc_signature(signature)
        values = signature.to_h
        "#{colorize('ECCSignature', :class)} r=#{colorize(values[:r], :integer)}, s=#{colorize(values[:s], :integer)}"
      end
    end
  end
end
