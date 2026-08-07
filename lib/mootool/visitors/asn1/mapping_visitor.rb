# frozen_string_literal: true

module MooTool
  module Visitors
    module ASN1
      # Visitor that maps ASN1 structures to native Ruby types.
      #
      # Works with both OpenSSL::ASN1 and RASN1::Types nodes via adapters.
      #
      # Transforms ASN1 primitives into their natural Ruby equivalents:
      # - INTEGER → Integer
      # - BOOLEAN → true/false
      # - NULL → nil
      # - OCTET_STRING, BIT_STRING → String (binary)
      # - UTF8STRING, IA5STRING, PRINTABLESTRING, etc. → String
      # - OBJECT → String (OID dotted notation)
      # - UTCTIME, GENERALIZEDTIME → Time
      # - SEQUENCE, SET → Array
      # - PRIVATE tagged nodes → Hash with 4CC key
      #
      # @example
      #   der = File.binread('certificate.der')
      #   asn1 = OpenSSL::ASN1.decode(der)
      #   visitor = MooTool::Visitors::MappingVisitor.new
      #   native = visitor.visit(asn1)
      class MappingVisitor < VisitorBase
        # Maps a primitive ASN1 node to its native Ruby type.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the primitive node.
        # @return [Object] The native Ruby value.
        def visit_primitive(adapter)
          return adapter.value if adapter.value.nil?

          if adapter.null?
            nil
          elsif adapter.integer? || adapter.enumerated?
            adapter.native_value
          elsif adapter.boolean?
            adapter.value
          elsif adapter.octet_string? || adapter.bit_string?
            adapter.value
          elsif adapter.string_type?
            adapter.value
          elsif adapter.object_id?
            adapter.value
          elsif adapter.utc_time? || adapter.generalized_time?
            adapter.value
          else
            adapter.native_value
          end
        end

        # Maps a constructive ASN1 node using its already-visited children.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the constructive node.
        # @param children [Array<Object>] The mapped children.
        # @return [Array<Object>] The children array.
        def visit_constructive(_adapter, children)
          children
        end

        # Maps a PRIVATE-tagged ASN1 node to a Hash with its 4CC label as key.
        #
        # @param adapter [MooTool::Visitors::Adapters::AdapterBase] The adapter wrapping the PRIVATE-tagged node.
        # @return [Hash{Symbol => Object}] A hash with the 4CC key and mapped value.
        def visit_private(adapter)
          label = adapter.tag_label

          if adapter.value.is_a?(Array)
            @parents.push(adapter)
            @depth += 1

            children = adapter.children.map { |child| visit(child) }

            @depth -= 1
            @parents.pop

            { label => children }
          else
            { label => adapter.value }
          end
        end
      end
    end
  end
end
