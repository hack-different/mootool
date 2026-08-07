# frozen_string_literal: true

module MooTool
  module Visitors
    module ASN1
      module Adapters
        # Adapter for OpenSSL::ASN1 nodes.
        #
        # Wraps OpenSSL::ASN1::ASN1Data objects to conform to the common
        # {MooTool::Visitors::Adapters::AdapterBase} interface used by visitors.
        class OpenSSLAdapter < AdapterBase
          # @return [Integer] The ASN1 tag number.
          def tag
            @node.tag
          end

          # @return [Symbol] The tag class as an uppercase symbol (:UNIVERSAL, :PRIVATE, etc.).
          def tag_class
            @node.tag_class
          end

          # @return [Object] The raw value of the node.
          def value
            @node.value
          end

          # @return [Boolean] True if the node is a constructed type.
          def constructed?
            @node.is_a?(OpenSSL::ASN1::Constructive) ||
              (private_tag? && @node.value.is_a?(Array))
          end

          # @return [Symbol, Integer] The tag label (4CC symbol for PRIVATE tags).
          def tag_label
            if @node.respond_to?(:tag_label)
              @node.tag_label
            else
              @node.tag
            end
          end

          # Returns wrapped adapter children for constructed nodes.
          #
          # @return [Array<MooTool::Visitors::Adapters::AdapterBase>]
          def children
            return [] unless @node.value.is_a?(Array)

            @node.value.map { |child| Adapters::AdapterBase.wrap(child) }
          end

          # Returns the native Ruby value, converting OpenSSL::BN to Integer.
          #
          # @return [Object]
          def native_value
            val = @node.value
            val.is_a?(OpenSSL::BN) ? val.to_i : val
          end
        end
      end
    end
  end
end
