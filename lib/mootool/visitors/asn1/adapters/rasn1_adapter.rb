# frozen_string_literal: true

require 'rasn1'

module MooTool
  module Visitors
    module ASN1
      module Adapters
        # Adapter for RASN1Adapter::Types::Base nodes.
        #
        # Wraps RASN1Adapter type objects to conform to the common
        # {MooTool::Visitors::Adapters::AdapterBase} interface used by visitors.
        class RASN1Adapter < AdapterBase
          # @return [Integer] The ASN1 tag number.
          def tag
            @node.id
          end

          # Returns the tag class as an uppercase symbol to match OpenSSL convention.
          #
          # RASN1Adapter uses lowercase symbols (:universal, :private, etc.) while the
          # adapter interface uses uppercase (:UNIVERSAL, :PRIVATE, etc.).
          #
          # @return [Symbol] The tag class as an uppercase symbol.
          def tag_class
            @node.asn1_class.to_s.upcase.to_sym
          end

          # @return [Object] The raw value of the node.
          def value
            @node.value
          end

          # @return [Boolean] True if the node is a constructed type.
          def constructed?
            @node.constructed?
          end

          # @return [Symbol, Integer] The tag label (4CC symbol for PRIVATE tags, or tag number).
          def tag_label
            t = tag
            if private_tag? && t.respond_to?(:to_4cc)
              t.to_4cc
            else
              t
            end
          end

          # Returns wrapped adapter children for constructed nodes.
          #
          # @return [Array<MooTool::Visitors::Adapters::AdapterBase>]
          def children
            val = @node.value
            return [] unless val.is_a?(Array)

            val.map { |child| Adapters::AdapterBase.wrap(child) }
          end

          # Returns the native Ruby value.
          #
          # @return [Object]
          def native_value
            @node.value
          end
        end
      end
    end
  end
end
