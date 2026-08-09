# frozen_string_literal: true

module MooTool
  module Visitors
    module ASN1
      module Adapters
        # Common interface for ASN1 node adapters.
        #
        # Wraps nodes from different ASN1 libraries (OpenSSL, RASN2) to provide
        # a uniform API for the visitor pattern. Subclasses must implement
        # all abstract methods.
        #
        # @abstract Subclass and implement {#tag}, {#tag_class}, {#value},
        #   {#constructed?}, {#primitive?}, {#private_tag?}, {#context_specific?},
        #   {#universal?}, {#tag_label}, {#null?}, {#integer?}, {#boolean?},
        #   {#octet_string?}, {#bit_string?}, {#utf8_string?}, {#ia5_string?},
        #   {#printable_string?}, {#object_id?}, {#utc_time?}, {#generalized_time?},
        #   {#enumerated?}, {#children}, and {#native_value}.
        class AdapterBase
          # @return [Object] The underlying ASN1 node from the original library.
          attr_reader :node

          # Wraps the given ASN1 node.
          #
          # @param node [Object] The ASN1 node to wrap.
          def initialize(node)
            @node = node
          end

          # Returns the ASN1 tag number.
          #
          # @return [Integer]
          # @abstract
          def tag
            raise NotImplementedError
          end

          # Returns the ASN1 tag class as an uppercase symbol.
          #
          # @return [Symbol] One of :UNIVERSAL, :CONTEXT_SPECIFIC, :PRIVATE, :APPLICATION.
          # @abstract
          def tag_class
            raise NotImplementedError
          end

          # Returns the node's value.
          #
          # @return [Object]
          # @abstract
          def value
            raise NotImplementedError
          end

          # Returns true if this node is a constructed type (Sequence, Set, etc.).
          #
          # @return [Boolean]
          # @abstract
          def constructed?
            raise NotImplementedError
          end

          # Returns true if this node is a primitive type.
          #
          # @return [Boolean]
          def primitive?
            !constructed?
          end

          # Returns true if this node uses a PRIVATE tag class.
          #
          # @return [Boolean]
          def private_tag?
            tag_class == :PRIVATE
          end

          # Returns true if this node uses a CONTEXT_SPECIFIC tag class.
          #
          # @return [Boolean]
          def context_specific?
            tag_class == :CONTEXT_SPECIFIC
          end

          # Returns true if this node uses a UNIVERSAL tag class.
          #
          # @return [Boolean]
          def universal?
            tag_class == :UNIVERSAL
          end

          # Returns the tag label, typically a 4CC symbol for PRIVATE tags.
          #
          # @return [Symbol, Integer]
          # @abstract
          def tag_label
            raise NotImplementedError
          end

          # @return [Boolean]
          def null?
            tag == 5
          end

          # @return [Boolean]
          def integer?
            tag == 2 && universal?
          end

          # @return [Boolean]
          def boolean?
            tag == 1 && universal?
          end

          # @return [Boolean]
          def octet_string?
            tag == 4 && universal?
          end

          # @return [Boolean]
          def bit_string?
            tag == 3 && universal?
          end

          # @return [Boolean]
          def utf8_string?
            tag == 12 && universal?
          end

          # @return [Boolean]
          def ia5_string?
            tag == 22 && universal?
          end

          # @return [Boolean]
          def printable_string?
            tag == 19 && universal?
          end

          # @return [Boolean]
          def t61_string?
            tag == 20 && universal?
          end

          # @return [Boolean]
          def numeric_string?
            tag == 18 && universal?
          end

          # @return [Boolean]
          def universal_string?
            tag == 28 && universal?
          end

          # @return [Boolean]
          def bmp_string?
            tag == 30 && universal?
          end

          # @return [Boolean]
          def object_id?
            tag == 6 && universal?
          end

          # @return [Boolean]
          def utc_time?
            tag == 23 && universal?
          end

          # @return [Boolean]
          def generalized_time?
            tag == 24 && universal?
          end

          # @return [Boolean]
          def enumerated?
            tag == 10 && universal?
          end

          # @return [Boolean]
          def string_type?
            utf8_string? || ia5_string? || printable_string? || t61_string? ||
              numeric_string? || universal_string? || bmp_string?
          end

          # Returns wrapped child adapters for constructed nodes.
          #
          # @return [Array<MooTool::Visitors::Adapters::AdapterBase>]
          # @abstract
          def children
            raise NotImplementedError
          end

          # Returns the native Ruby value extracted from this node.
          #
          # @return [Object]
          # @abstract
          def native_value
            raise NotImplementedError
          end

          # Wraps an ASN1 node with the appropriate adapter.
          #
          # Detects whether the node is from OpenSSL or RASN2 and returns
          # the corresponding adapter.
          #
          # @param node [Object] An ASN1 node from OpenSSL or RASN2.
          # @return [MooTool::Visitors::Adapters::AdapterBase] The wrapped adapter.
          # @raise [ArgumentError] If the node type is not recognized.
          def self.wrap(node)
            case node
            when OpenSSL::ASN1::ASN1Data
              OpenSSLAdapter.new(node)
            when RASN2::Types::Base
              RASN2Adapter.new(node)
            else
              raise ArgumentError, "unsupported ASN1 node type: #{node.class}"
            end
          end
        end
      end
    end
  end
end
