# frozen_string_literal: true

module MooTool
  module Schemas
    module ASN1
      # A RASN2 type describing an Apple private ASN.1 tag.
      #
      # Apple encodes most of its container structures as +[PRIVATE <4cc>] EXPLICIT <content>+,
      # where +<4cc>+ is the big endian integer value of a four character code (+MANP+, +OBJP+,
      # +prid+, ...). Because that identifier changes for every single tag, RASN2 cannot express
      # them through the static +:explicit+ option: the identifier is only known once the data has
      # been parsed.
      #
      # This type therefore matches *any* private, constructed identifier, remembers the value it
      # decoded, and exposes it as a four character code through {#four_cc}. The wrapped content is
      # declared per subclass with {ClassMethods#wraps} and defaults to +ANY+, so an undescribed tag
      # still parses and round-trips.
      #
      # @example Describe a tag wrapping a known model
      #   class MyTag < MooTool::Schemas::ASN1::PrivateTag
      #     wraps MyModel
      #   end
      #
      #   tag = MyTag.parse(der)
      #   tag.four_cc # => :MANP
      #   tag.value   # => MyModel
      #
      # @example Accept any tag holding any value
      #   tag = MooTool::Schemas::ASN1::PrivateTag.parse(der)
      #   tag.four_cc # => :OBJP
      #   tag.value   # => RASN2::Types::Any
      class PrivateTag < RASN2::Types::Constructed
        # Fallback identifier, used when neither a +:four_cc+ option was given nor data was parsed.
        # @return [Integer]
        ID = 0

        # Options forced on every instance: Apple 4CC tags are always private and constructed.
        # @return [Hash{Symbol => Object}]
        DEFAULT_OPTIONS = { class: :private, constructed: true }.freeze

        # Class level DSL of {PrivateTag}.
        module ClassMethods
          # Declare the type explicitly wrapped by this tag.
          #
          # @param type [Class] a {RASN2::Model} or {RASN2::Types::Base} subclass
          # @return [Class] +type+
          def wraps(type)
            @wrapped_type = type
          end

          # The type explicitly wrapped by this tag.
          #
          # @return [Class] defaults to +RASN2::Types::Any+ when {#wraps} was never called
          def wrapped_type
            return @wrapped_type if defined?(@wrapped_type)

            superclass.respond_to?(:wrapped_type) ? superclass.wrapped_type : RASN2::Types::Any
          end

          # Build a new instance of the wrapped type.
          #
          # @return [RASN2::Model, RASN2::Types::Base]
          def new_wrapped_element
            wrapped_type.new
          end

          # Convert a four character code into its ASN.1 identifier value.
          #
          # @param four_cc [String, Symbol, Integer] the code to convert
          # @return [Integer] the big endian integer value of +four_cc+
          def four_cc_to_id(four_cc)
            return four_cc if four_cc.is_a?(::Integer)

            four_cc.to_s.b.unpack1('N')
          end

          # ASN.1 type name, as displayed by {RASN2::Types::Base#inspect}.
          #
          # @return [String]
          def type
            'PRIVATE TAG'
          end
        end

        extend ClassMethods

        # @param options [Hash]
        # @option options [String, Symbol, Integer] :four_cc restrict this tag to a single code
        # @see RASN2::Types::Base#initialize
        def initialize(options = {})
          super(DEFAULT_OPTIONS.merge(options))
        end

        # Resolve the +:four_cc+ option into an expected identifier value.
        #
        # @return [void]
        def specific_initializer
          four_cc = @options[:four_cc]
          return if four_cc.nil?

          @expected_id = self.class.four_cc_to_id(four_cc)
          @id_value = @expected_id
        end

        # The tag identifier rendered as a four character code.
        #
        # @return [Symbol, Integer] the 4CC, or the raw identifier when it is not a 4CC
        def four_cc
          id.to_4cc
        end

        # An empty tag holds nothing.
        #
        # @return [nil]
        def void_value
          nil
        end

        # Parse the explicitly wrapped content.
        #
        # @param der [String] the tag content, without identifier nor length octets
        # @param ber [Boolean] whether BER encoding is accepted
        # @return [RASN2::Model, RASN2::Types::Base] the parsed content
        def der_to_value(der, ber: false)
          element = self.class.new_wrapped_element
          element.parse!(der, ber: ber)
          @value = element
        end

        # A hash image of the tag, keyed by its four character code.
        #
        # @return [Hash{Symbol, Integer => Object}]
        def to_h
          { four_cc => unwrapped_value }
        end

        # The wrapped content, reduced to plain Ruby objects whenever possible.
        #
        # @return [Object, nil]
        def unwrapped_value
          case @value
          when RASN2::Model then @value.to_h.values.first
          when RASN2::Types::Base then @value.value
          else @value
          end
        end

        # @param level [Integer]
        # @return [String]
        def inspect(level = 0)
          lvl = [level, 0].max
          str = +('  ' * lvl)
          str << "#{@name} " unless @name.nil?
          str << "PRIVATE [#{four_cc}] EXPLICIT #{type}:"
          return str << ' (NO VALUE)' unless value?

          str << "\n" << @value.inspect(lvl + 1)
        end

        # Accept any private constructed identifier, and remember the one which was decoded.
        #
        # @param der [String] DER binary data
        # @return [Boolean] +true+ when +der+ starts with an acceptable identifier
        # @raise [RASN2::ASN1Error] identifier is not acceptable and the tag is mandatory
        def check_id(der) # rubocop:disable Naming/PredicateMethod
          asn1_class, pc, id, = RASN2::Types.decode_identifier_octets(der) unless der.nil? || der.empty?

          if (asn1_class == :private) && (pc == :constructed) && (@expected_id.nil? || (@expected_id == id))
            @id_value = id
            return true
          end

          apply_id_fallbacks(der)
          false
        end

        # Apply the +OPTIONAL+ / +DEFAULT+ fallbacks when the identifier does not match.
        #
        # @param der [String] DER binary data
        # @return [void]
        # @raise [RASN2::ASN1Error] the tag is neither optional nor defaulted
        def apply_id_fallbacks(der)
          if optional?
            @no_value = true
            @value = void_value
          elsif @default.nil?
            raise_id_error(der)
          else
            @value = @default
          end
        end

        # @return [String]
        def value_to_der
          case @value
          when RASN2::Types::Base, RASN2::Model, RASN2::Wrapper then @value.to_der
          else @value.to_s
          end
        end

        # @return [PrivateTag]
        def explicit_type
          self.class.new(name: name)
        end
      end
    end
  end
end
