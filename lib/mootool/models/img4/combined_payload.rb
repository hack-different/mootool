# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # A payload that contains multiple IMG4 file payloads.
      class CombinedPayload
        include Helpers::IMG4

        # Initializes a new CombinedPayload from raw ASN.1 data.
        #
        # @param data [String, OpenSSL::ASN1::ASN1Data] The raw ASN.1 data or an ASN.1 object to parse.
        def initialize(data)
          @value = construct(data)
          @content = @value.drop(1).map do |entry|
            { entry[0] => File.new(entry[1]) }
          end.reduce(&:merge)
        end

        # Retrieves raw hashes from all nested payloads.
        #
        # @return [Array<Hash>] A flattened array of hash entries for each nested payload.
        def raw_hashes
          @content.map do |key, value|
            value.raw_hashes(key)
          end.flatten
        end

        # Converts the combined payload into a tree structure representation.
        #
        # @return [Helpers::TreeNode] The root node of the generated tree.
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
