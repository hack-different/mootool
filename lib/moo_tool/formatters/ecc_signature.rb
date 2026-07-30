# frozen_string_literal: true

module MooTool
  module Formatters
    module ECCSignature
      def awesome_ecc_signature(signature)
        values = signature.to_h
        "#{colorize('ECCSignature', :class)} r=#{colorize(values[:r], :integer)}, s=#{colorize(values[:s], :integer)}"
      end
    end
  end
end
