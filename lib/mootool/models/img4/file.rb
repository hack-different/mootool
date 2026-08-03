# frozen_string_literal: true

# An instance of a IMG4 file
module MooTool
  module Models
    module IMG4
      # An IMG4 file, or, occasionally, a file read in from another source
      class File
        attr_reader :file_index

        include MooTool::Helpers::IMG4
        include Helpers::Signature
        include Helpers::File
        include Helpers::Hashing

        def to_tree_hashes(node)
          hash_nodes = named_hashes.map do |id, h|
            Helpers::TreeNode.new(id.ai, [Helpers::TreeNode.new(h.ai)])
          end
          node.children << Helpers::TreeNode.new('Hashes', hash_nodes) if hash_nodes.any?
        end

        def to_tree_validations(node)
          validation_nodes = validate_signature.map do |id, v|
            Helpers::TreeNode.new(id.ai, [Helpers::TreeNode.new(v.ai)])
          end
          node.children << Helpers::TreeNode.new('Validation', validation_nodes) if validation_nodes.any?
          return unless @content[:IM4M]

          node.children << Helpers::TreeNode.new('Certificate Validations', @content[:IM4M].validate.map { |id, v|
            Helpers::TreeNode.new(id.ai, [Helpers::TreeNode.new(v.ai)])
          })
        end

        def to_tree
          node = Helpers::TreeNode.new(Models::IMG4.key_name(:IMG4))
          @content.each_value { |value| node.children << value.to_tree }
          to_tree_hashes(node)
          to_tree_validations(node)

          node
        end

        def manifest
          @content[:IM4M]
        end

        def payload_type
          @content[:IM4P]&.type&.to_sym
        end

        def manifest_type
          @content[:IM4M]&.type&.to_sym
        end

        def initialize(der, filename = nil)
          MooTool::Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
          @filename = filename

          raw_data = der.is_a?(MooTool::Models::Digest) ? der.value : der

          @hash_data = [raw_data]
          @data = OpenSSL::ASN1.decode(raw_data)
          @type = @data.value[0].value
          @content = {}
          parse
        end

        def validated_certificate_chain
          @content[:IM4M].certificates.last
        end

        def to_h
          result = @content.dup
          result[:comb] = @content[:comb].transform_values(&:to_h) if result[:comb]
          result[:hashes] = named_hashes
          result[:validation] = validate_signature
          result[:certificate_validation] = @certificate_validation
          result.deep_symbolize_keys
        end

        def types
          result = [payload_type]
          result += @content[:comb].keys if @content[:comb]
          result += @content[:secb].keys if @content[:secb]
          result.compact.map(&:to_sym)
        end

        def payload
          @content[:IM4P]&.payload
        end

        def payload?
          !@content[:IM4P].nil?
        end

        def manifest?
          !@content[:IM4M].nil?
        end

        def basename
          basename = ::File.basename(@filename)
          extension = ::File.extname(basename)
          "#{basename.chomp(extension)}.#{@type}"
        end

        def extract_payload
          output_path = ::File.join(::File.dirname(@filename), basename)
          ::File.write(output_path, @payload)
        end

        def hashes
          raw_hashes.map do |hash_pair|
            hash_kind = hash_pair[:kind]
            hash = hash_pair[:value]
            Models::Digest.new(::Digest::SHA384.digest(hash), hash_kind)
          end
        end

        def raw_hashes
          results = []
          results += @content[:IM4M]&.raw_hashes if @content[:IM4M]
          results += @content[:IM4P]&.raw_hashes if @content[:IM4P]

          results.compact.uniq
        end

        def public_keys
          results = {}
          results.merge! @content[:IM4M]&.public_keys if @content[:IM4M]
          results.merge! @content[:secb]&.public_keys if @content[:secb]
          results.merge! @content[:comb]&.public_keys if @content[:comb]

          results
        end

        def print
          ap(to_h.deep_transform_keys { |k| Models::IMG4.key_name(k) })
        end

        private

        def parse
          case @type
          when 'IM4P'
            @content[:IM4P] = MooTool::Models::IMG4::IMG4Payload.new(@data)
          when 'IM4M'
            @content[:IM4M] = MooTool::Models::IMG4::IMG4Manifest.new(@data)
          when 'IMG4'
            @content[:IM4P] = MooTool::Models::IMG4::IMG4Payload.new(@data.value[1])
            @content[:IM4M] = MooTool::Models::IMG4::IMG4Manifest.new(@data.value[2])
          when 'secb'
            @content[:secb] = MooTool::Models::IMG4::SecurityBody.new(@data)
          when 'comb'
            @content[:comb] = MooTool::Models::IMG4::CombinedPayload.new(@data)
          else
            @content = @value.map(&:to_h).reduce(&:merge)
          end

          validate
        end

        def validate
          @content[:IM4P].validate @content[:IM4M] if @content[:IM4P] && @content[:IM4M]

          return unless @content[:IM4M]

          @certificate_validation = @content[:IM4M].validate
        end

        def signed_data
          @content[:IM4M]&.signed_data
        end

        def signatures
          results = []
          results << { kind: :IM4M, value: @content[:IM4M]&.signature } if @content[:IM4M]
          results
        end
      end
    end
  end
end
