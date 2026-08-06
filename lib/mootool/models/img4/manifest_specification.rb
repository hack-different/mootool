# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Part of certificates indicating the presence or values in a signed manifest that are delegated
      class ManifestSpecification
        include MooTool::Helpers::IMG4

        def initialize(input)
          @value = decode_construct(input)
          @composite = {}
          @value.each do |entry|
            @composite.merge!(entry.to_h)
          end
          @manifest_properties = @composite[:MANP] || {}
          @object_properties = @composite[:OBJP] || {}
        end

        def to_h
          @value
        end

        def inspect
          to_h.ai
        end

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
