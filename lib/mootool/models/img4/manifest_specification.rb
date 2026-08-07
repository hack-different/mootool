# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a manifest specification within a certificate, defining delegated manifest and object properties.
      class ManifestSpecification
        include MooTool::Helpers::IMG4

        # Initializes a new ManifestSpecification from ASN.1 data.
        #
        # @param input [OpenSSL::ASN1::ASN1Data] The raw ASN.1 structure to decode.
        def initialize(input)
          @value = decode_construct(input)
          @composite = {}
          @value.each do |entry|
            @composite.merge!(entry.to_h)
          end
          @manifest_properties = @composite[:MANP] || {}
          @object_properties = @composite[:OBJP] || {}
        end

        # Returns the decoded internal value of the specification.
        #
        # @return [Object] The decoded value.
        def to_h
          @value
        end

        # Provides a human-readable inspection of the specification.
        #
        # @return [String] The awesome_print representation.
        def inspect
          to_h.ai
        end

        # Converts the specification into a tree structure for visualization.
        #
        # @return [Helpers::TreeNode] The root node of the generated tree.
        def to_tree
          node = Helpers::TreeNode.new('IMG4 Specification')

          manifest_properties_node = Helpers::TreeNode.new(Models::IMG4.key_name(:MANP))
          @manifest_properties.each do |key, manifest_property|
            manifest_properties_node.children << Helpers::TreeNode.new(Models::IMG4.key_name(key.to_sym), [Helpers::TreeNode.new(manifest_property.ai)])
          end

          object_properties_node = Helpers::TreeNode.new(Models::IMG4.key_name(:OBJP))
          @object_properties.each do |key, manifest_property|
            object_properties_node.children << Helpers::TreeNode.new(Models::IMG4.key_name(key.to_sym), [Helpers::TreeNode.new(manifest_property.ai)])
          end

          node.children << manifest_properties_node
          node.children << object_properties_node

          node
        end
      end
    end
  end
end
