# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents a Key/Value property in an IMG4 structure, using a PRIVATE ASN.1 tag.
      class KeyValueProperty
        include MooTool::Helpers::IMG4

        # @return [Symbol, String] The human-readable key name.
        attr_reader :key

        # @return [Object] The resolved value of the property.
        attr_reader :value

        # @return [OpenSSL::ASN1::ASN1Data] The original ASN.1 object.
        attr_reader :object

        # A sentinel value representing that any value is allowed or it couldn't be resolved.
        SPLAT_SENTINEL = :ALLOW_ANY_VALUE

        # Initializes a new KeyValueProperty from ASN.1 data.
        #
        # @param input [OpenSSL::ASN1::ASN1Data] The raw ASN.1 structure to parse.
        # @raise [MooTool::Error] If the property cannot be parsed.
        def initialize(input)
          KeyValueProperty.validate! input

          @key = Models::IMG4.key_name(input.tag.to_4cc)
          @object = input

          construction = construct(input.value.first)
          @value = resolve_value construction.last, input.tag
        rescue StandardError
          raise MooTool::Error,
                "Failure to parse KeyValueProperty: #{@key} with value #{@value} of type #{@value.class}"
        end

        # Converts the property to a hash.
        #
        # @return [Hash] A hash mapping the key to its value.
        def to_h
          { Models::IMG4.key_name(@key) => @value }
        end

        # Returns the property as a key-value pair.
        #
        # @return [Array(Symbol, Object)] An array containing the key and value.
        def to_pair
          [Models::IMG4.key_name(@key), @value]
        end

        # Converts the property into a tree structure for visualization.
        #
        # @return [Helpers::TreeNode] The root node of the generated tree.
        def to_tree
          if @value.respond_to? :to_tree
            @value.to_tree
          else
            Helpers::TreeNode.new(Models::IMG4.key_name(@key).ai, [TreeNode.new(@value.ai)])
          end
        end

        # Provides a string representation of the property.
        #
        # @return [String] The inspected hash.
        def inspect
          to_h.inspect
        end

        # Validates the ASN.1 structure of the property.
        #
        # @param input [OpenSSL::ASN1::ASN1Data] The input to validate.
        # @raise [RuntimeError, MooTool::Error] If the structure is invalid.
        # @return [void]
        def self.validate!(input)
          unless input.tag_class == :PRIVATE && input.is_a?(OpenSSL::ASN1::ASN1Data)
            raise 'Input must be a private instance of ASN1Data'
          end

          unless input.value.size == 1 &&
                 input.value[0].value.size == 2
            raise MooTool::Error,
                  "The sequence must have two values #{input.value[0].value.size}"
          end
        end

        private

        def resolve_value_tag(value, tag)
          case tag
          when *self.class::KEY_INSTANCE_TAGS
            value.nil? ? nil : MooTool::Models::Certificate.parse_sik(value)
          when *self.class::DECODE_TAGS
            decode_construct(value, tag.to_4cc)
          when *self.class::OCTET_TAGS
            value.is_a?(MooTool::Models::Digest) ? value : MooTool::Models::Digest.create(value)
          when *self.class::SIGNATURE_TAGS
            decode_construct(input.value[0].value[1].value, tag.to_4cc)
          else
            value
          end
        end

        def resolve_value(value, tag)
          value = value.first if value.is_a?(Array)
          case value
          when OpenSSL::ASN1::ASN1Data, nil
            SPLAT_SENTINEL
          else
            resolve_value_tag(value, tag)
          end
        end
      end
    end
  end
end
