# frozen_string_literal: true

module MooTool
  module Schemas
    module ASN1
      # The IMG4 manifest specification carried by an Apple signing certificate.
      #
      # It declares which manifest (+MANP+) and object (+OBJP+) properties a signing server is
      # allowed to delegate, and is expressed with Apple private four character code tags:
      #
      #   ManifestSpecification ::= SET OF PropertySetTag
      #
      #   PropertySetTag ::= [PRIVATE <4cc>] EXPLICIT PropertySet
      #   PropertySet    ::= SEQUENCE {
      #     key        IA5String,
      #     properties SET OF PropertyTag
      #   }
      #
      #   PropertyTag ::= [PRIVATE <4cc>] EXPLICIT Property
      #   Property    ::= SEQUENCE {
      #     key   IA5String,
      #     value [0] EXPLICIT ANY
      #   }
      #
      # Every private identifier is the big endian value of the +key+ it precedes, and may be any
      # four character code; {PrivateTag} takes care of accepting them all.
      #
      # @example
      #   specification = MooTool::Schemas::ASN1::ManifestSpecification.parse(der)
      #   specification.to_h # => { MANP: { faic: nil, inst: nil }, OBJP: { DGST: nil, ... } }
      class ManifestSpecification < RASN2::Model
        # A single delegated property, whose value may be of any ASN.1 type.
        class Property < RASN2::Model
          sequence :property do
            ia5_string(:key)
            choice :value do
              null(:VALUE_NULL)
              boolean(:VALUE_BOOLEAN)
              integer(:VALUE_INTEGER)
              tag(:MUST_BE_SET, class: :context, tag: 0) do
                null(:MUST_BE_SET_NULL)
              end
              tag(:MUST_NOT_BE_SET, class: :context, tag: 1) do
                null(:MUST_NOT_BE_SET_NULL)
              end
              bit_string(:VALUE_BIT_STRING)
              octet_string(:VALUE_OCTET_STRING)
              any(:VALUE_ANY)
            end
          end
        end

        # A property, tagged with the private 4CC repeating its key.
        class PropertyTag < PrivateTag
          wraps Property
        end

        # A named group of delegated properties, such as +MANP+ or +OBJP+.
        class PropertySet < RASN2::Model
          sequence :property_set,
                   content: [ia5_string(:key),
                             set_of(:properties, PropertyTag)]
        end

        # A property group, tagged with the private 4CC repeating its key.
        class PropertySetTag < PrivateTag
          wraps PropertySet
        end

        set_of(:ManifestSpecification, PropertySetTag)

        # The tags of every property group of this specification.
        #
        # @return [Array<PropertySetTag>]
        def tags
          root.value || []
        end

        # The four character codes of every property group, in encounter order.
        #
        # @return [Array<Symbol>]
        def four_ccs
          tags.map(&:four_cc)
        end

        # Access a model element by name or index, or a property group by its four character code.
        #
        # @param name_or_index [Symbol, String, Integer] +:manifest_specification+, an index, or a
        #   group 4CC such as +:MANP+
        # @return [Object, nil]
        def [](name_or_index)
          element = super
          return element unless element.nil?
          return nil unless name_or_index.respond_to?(:to_sym)

          to_h[name_or_index.to_sym]
        end

        # A plain Ruby image of the whole specification.
        #
        # @return [Hash{Symbol => Hash{Symbol => Object}}] property groups, mapping each property
        #   four character code to its decoded value (+nil+ for the usual +NULL+ placeholder)
        def to_h
          tags.to_h { |tag| [tag.four_cc, properties_of(tag)] }
        end

        private

        # @param tag [PropertySetTag]
        # @return [Hash{Symbol => Object}]
        def properties_of(tag)
          tag.value[:properties].value.to_h do |property_tag|
            [property_tag.four_cc, decode(property_tag.value[:value].value)]
          end
        end

        # Decode the +ANY+ payload of a property.
        #
        # @param der [String, nil] the DER encoded value
        # @return [Object, nil]
        def decode(der)
          return nil if der.nil? || der.empty?

          decoded = RASN2.parse(der)
          decoded.is_a?(::Array) ? decoded.map(&:value) : decoded.value
        end
      end
    end
  end
end
