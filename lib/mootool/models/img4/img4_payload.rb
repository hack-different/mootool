# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents an IMG4 Payload (IM4P), which contains the actual firmware data and its metadata.
      class IMG4Payload
        include MooTool::Helpers::IMG4
        include Helpers::Hashing

        # @return [String, nil] The signature if present.
        attr_reader :signature

        # @return [Models::Decompressor] The decompressor wrapping the raw payload data.
        attr_reader :payload

        # @return [String] The four-character tag identifying the payload type (e.g., 'ibot').
        attr_reader :type

        # Mapping of keybag type identifiers to their symbolic names.
        KEYBAG_TYPES = {
          1 => :PROD,
          2 => :DEV
        }.freeze

        # Converts the payload into a tree structure for visualization.
        #
        # @return [Helpers::TreeNode] The root node of the generated tree.
        def to_tree
          Helpers::TreeNode.new(Models::IMG4.key_name(:IM4P).ai, [
                                  Helpers::TreeNode.new("Type: #{Models::IMG4.key_name(@type).ai}"),
                                  Helpers::TreeNode.new("Description: #{@description.ai}"),
                                  @payload.to_tree
                                ])
        end

        # Initializes a new IMG4Payload from ASN.1 data.
        #
        # @param input [OpenSSL::ASN1::ASN1Data] The raw ASN.1 structure to parse.
        def initialize(input)
          @input = input
          @type = input.value[1].value
          @description = input.value[2].value
          @payload = MooTool::Models::Decompressor.new(input.value[3].value, @type)
          @keybag = parse_keybag(input.value[4]) if input.value[4]
          @validated = nil

          return unless input.value[5]

          @extensions = construct(input.value[5]).map do |extension|
            { extension[0] => extension[1].map(&:to_h).reduce({}, :merge) }
          end.reduce(&:merge)
        end

        # Parses keybag information from a raw ASN.1 object.
        #
        # @param input [OpenSSL::ASN1::ASN1Data] The encoded keybag data.
        # @return [Hash, Array, Object] The parsed keybag mapping or raw object if parsing fails.
        def parse_keybag(input)
          value = construct(OpenSSL::ASN1.decode(input))
          return value unless value.is_a? Array

          return value unless value.all?(OpenSSL::ASN1)

          value.map do |keybag|
            iv = Models::Digest.create(keybag[1].raw, 'IV')
            { KEYBAG_TYPES[keybag[0]] => { iv: iv, key: keybag[2] } }
          end.reduce(&:merge)
        end

        # Validates the payload against an IMG4 manifest.
        #
        # @param manifest [IMG4Manifest] The manifest containing expected digests.
        # @return [Hash] A validation status hash with :valid and :hash keys.
        def validate(manifest)
          firmware_tag = manifest.firmware_tag(@type)
          return nil unless firmware_tag

          match = hashes.select do |hash|
            puts(firmware_tag.ai) if firmware_tag.is_a? Array
            hash == firmware_tag.digest
          end
          @validated = {
            valid: match.any?,
            hash: match.first
          }
        end

        # Converts the payload and its metadata into a hash representation.
        #
        # @return [Hash] A hash containing type, description, payload, and other metadata.
        def to_h
          result = { type: @type, description: @description, payload: @payload }

          result[:keybag] = @keybag if @keybag
          result[:extensions] = @extensions if @extensions
          result[:payload_hashes] = named_hashes
          result[:validated] = @validated if @validated
          result
        end

        # Returns a human-readable inspection of the payload.
        #
        # @return [String] The awesome_print representation.
        def inspect
          to_h.ai
        end

        # Returns the DER-encoded bytes of the payload structure.
        #
        # @return [String] The raw DER bytes.
        def to_bytes
          @input.to_der
        end

        # Retrieves all raw hashes for this payload.
        #
        # @return [Array<Hash>] An array of hash entries for the payload and its components.
        def raw_hashes
          [{ kind: :'IM4P@to_bytes', value: to_bytes }] + @payload.raw_hashes
        end
      end
    end
  end
end
