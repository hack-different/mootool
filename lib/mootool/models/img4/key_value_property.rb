# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Key/Value Properties are those with an ASN 4CC tag, and contain exactly two elements in a sequence, the first
      # is a simple repeat of the key name as a string the second is the value of the property.
      class KeyValueProperty
        include MooTool::Helpers::IMG4

        attr_reader :key, :value, :object

        SPLAT_SENINEL = :ALLOW_ANY_VALUE

        def initialize(input)
          unless input.tag_class == :PRIVATE && input.is_a?(OpenSSL::ASN1::ASN1Data)
            raise 'Input must be a private instance of ASN1Data'
          end
          @key = input.tag.to_4cc

          @object = input

          unless input.value.size == 1 &&
                 input.value[0].value.size == 2
            raise MooTool::Error,
                  "The sequence must have two values #{input.value[0].value.size}"
          end

          construction = construct(input.value.first)

          @key = construction.first.to_sym
          @value = construction.last

          @value = @value.first if @value.is_a?(Array)

          # @value = SPLAT_SENINEL if @value.nil?
          # @value = nil if @value.is_a?(OpenSSL::ASN1::ASN1Data) && @value.value.nil?
          @value = SPLAT_SENINEL if @value.is_a?(OpenSSL::ASN1::ASN1Data) && @value.value.nil?

          return if @value == SPLAT_SENINEL

          if KEY_INSTANCE_TAGS.include?(input.tag) && !@value.nil?
            @value = MooTool::Models::Certificate.parse_sik(@value)
          end

          @value = decode_construct(@value) if DECODE_TAGS.include?(input.tag)

          if OCTET_TAGS.include?(input.tag) && !@value.is_a?(MooTool::Models::Digest)
            @value = MooTool::Models::Digest.create(@value)
          end

          return unless SIGNATURE_TAGS.include?(input.tag)

          @value = decode_construct(input.value[0].value[1].value)
        rescue StandardError
          raise MooTool::Error,
                "Failure to parse KeyValueProperty: #{@key} with value #{@value} of type #{@value.class}"
        end

        def to_h
          { @key => @value }
        end

        def inspect
          to_h.inspect
        end
      end
    end
  end
end
