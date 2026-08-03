# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Key/Value Properties are those with an ASN 4CC tag, and contain exactly two elements in a sequence, the first
      # is a simple repeat of the key name as a string the second is the value of the property.
      class KeyValueProperty
        include MooTool::Helpers::IMG4

        attr_reader :key, :value, :object

        SPLAT_SENTINEL = :ALLOW_ANY_VALUE

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

        def to_h
          { Models::IMG4.key_name(@key) => @value }
        end

        def to_pair
          [Models::IMG4.key_name(@key), @value]
        end

        def to_tree
          if @value.respond_to? :to_tree
            @value.to_tree
          else
            Helpers::TreeNode.new(Models::IMG4.key_name(@key).ai, [TreeNode.new(@value.ai)])
          end
        end

        def inspect
          to_h.inspect
        end

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
            decode_construct(value)
          when *self.class::OCTET_TAGS
            value.is_a?(MooTool::Models::Digest) ? value : MooTool::Models::Digest.create(value)
          when *self.class::SIGNATURE_TAGS
            decode_construct(input.value[0].value[1].value)
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
