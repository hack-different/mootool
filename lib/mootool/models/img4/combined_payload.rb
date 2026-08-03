# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # A payload that contains N other file payloads
      class CombinedPayload
        include Helpers::IMG4

        def initialize(data)
          @value = construct(data)
          @content = @value.drop(1).map do |entry|
            { entry[0] => File.new(entry[1]) }
          end.reduce(&:merge)
        end

        def to_tree
          node = Helpers::TreeNode.new(Models::IMG4.key_name(:secb))

          @content.each do |key, value|
            child = Helpers::TreeNode.new(Models::IMG4.key_name(key))
            child.children << if value.respond_to?(:to_tree)
                                value.to_tree
                              else
                                Helpers::TreeNode.new(value.ai)
                              end
            node.children << child
          end

          node
        end
      end
    end
  end
end
