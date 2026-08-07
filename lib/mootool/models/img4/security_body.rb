# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a security body (secb) within an IMG4 structure, containing security-related metadata.
      class SecurityBody
        include MooTool::Helpers::IMG4

        # Initializes a new SecurityBody from raw data or an ASN.1 object.
        #
        # @param data [String, OpenSSL::ASN1::ASN1Data] The raw bytes or ASN.1 structure to parse.
        def initialize(data)
          @data = data.is_a?(String) ? data : data.to_der
          @value = construct(data)
          @content = @value.drop(1).map do |entry|
            case entry[0]
            when 'trst', 'rssl'
              { entry[0].to_sym => File.parse_certificates(entry.drop(1)) }
            when 'rvok'
              { entry[0].to_sym => entry[1] }
            when 'trpk'
              { entry[0].to_sym => entry.drop(1).map { |e| MooTool::Models::ECCPublicKey.new e } }
            else
              { entry[0].to_sym => entry }
            end
          end.reduce(&:merge)
        end

        # Provides raw hashes for the security body.
        #
        # @return [Array<Hash>] An array containing the hash entry for the security body.
        def raw_hashes
          [{ kind: 'secb:hash', value: @data }]
        end

        # Converts the security body into a tree structure for visualization.
        #
        # @return [Helpers::TreeNode] The root node of the generated tree.
        def to_tree
          node = Helpers::TreeNode.new(Models::IMG4.key_name(:secb))

          @content.each do |key, value|
            child = Helpers::TreeNode.new(Models::IMG4.key_name(key))
            case value
            when Array
              value.each do |element|
                result_node = element.respond_to?(:to_tree) ? element.to_tree : Helpers::TreeNode.new(element.ai)
                child.children << result_node
              end
            else
              child.children << Helpers::TreeNode.new(value.ai)
            end
            node.children << child
          end

          node
        end
      end
    end
  end
end
