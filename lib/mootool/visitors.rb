# frozen_string_literal: true

module MooTool
  # Visitor pattern implementations for traversing ASN1 structures.
  #
  # Provides a base visitor with depth and parent tracking, along with
  # concrete visitors for mapping ASN1 to native Ruby types and for
  # validating structures against RASN2 models.
  #
  # Supports both OpenSSL::ASN1 and RASN2::Types nodes via the
  # {MooTool::Visitors::Adapters} adapter layer.
  module Visitors
  end
end
