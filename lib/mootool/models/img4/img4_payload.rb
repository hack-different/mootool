# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      # Represents an IM4P or payload
      class IMG4Payload
        include MooTool::Helpers::IMG4
        include Helpers::Hashing

        attr_reader :signature, :payload, :type

        KEYBAG_TYPES = {
          1 => :PROD,
          2 => :DEV
        }.freeze

        def to_tree
          Helpers::TreeNode.new(Models::IMG4.key_name(:IM4P).ai, [
                                  Helpers::TreeNode.new("Type: #{Models::IMG4.key_name(@type).ai}"),
                                  Helpers::TreeNode.new("Description: #{@description.ai}"),
                                  @payload.to_tree
                                ])
        end

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

        def parse_keybag(input)
          value = construct(OpenSSL::ASN1.decode(input))
          return value unless value.is_a? Array

          return value unless value.all?(OpenSSL::ASN1)

          value.map do |keybag|
            iv = Models::Digest.create(keybag[1].raw, 'IV')
            { KEYBAG_TYPES[keybag[0]] => { iv: iv, key: keybag[2] } }
          end.reduce(&:merge)
        end

        def validate(manifest)
          firmware_tag = manifest.firmware_tag(@type)

          match = hashes.select do |hash|
            hash == firmware_tag.digest
          end
          @validated = {
            valid: match.any?,
            hash: match.first
          }
        end

        def to_h
          result = { type: @type, description: @description, payload: @payload }

          result[:keybag] = @keybag if @keybag
          result[:extensions] = @extensions if @extensions
          result[:payload_hashes] = named_hashes
          result[:validated] = @validated if @validated
          result
        end

        def inspect
          to_h.ai
        end

        def to_bytes
          @input.to_der
        end

        def raw_hashes
          [{ kind: 'IM4P:to_bytes', value: to_bytes }] + @payload.raw_hashes
        end
      end
    end
  end
end
