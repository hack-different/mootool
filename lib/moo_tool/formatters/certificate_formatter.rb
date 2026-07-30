# frozen_string_literal: true

module MooTool
  module Formatters
    module CertificateFormatter
      def awesome_certificate(object)
        awesome_hash(object.to_h)
      end
    end
  end
end
