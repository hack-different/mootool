# frozen_string_literal: true

# An instance of a IMG4 file
module MooTool
  module Models
    module IMG4
      # Represents an IMG4 file, providing access to its components like payloads and manifests.
      class File
        # @return [Models::FileIndex, nil] The file index if loaded.
        attr_reader :file_index

        include MooTool::Helpers::IMG4
        include Helpers::Signature
        include Helpers::File
        include Helpers::Hashing

        # Appends hash information to a tree node.
        #
        # @param node [Helpers::TreeNode] The parent tree node.
        # @return [void]
        def to_tree_hashes(node)
          hash_nodes = named_hashes.map do |id, h|
            Helpers::TreeNode.new(id.ai, [Helpers::TreeNode.new(h.ai)])
          end
          node.children << Helpers::TreeNode.new('Hashes', hash_nodes) if hash_nodes.any?
        end

        # Appends validation information to a tree node.
        #
        # @param node [Helpers::TreeNode] The parent tree node.
        # @return [void]
        def to_tree_validations(node)
          validation_nodes = validate_signature.map do |v|
            Helpers::TreeNode.new(v.ai)
          end
          node.children << Helpers::TreeNode.new('Validation', validation_nodes) if validation_nodes.any?
          return unless @content[:IM4M]

          node.children << Helpers::TreeNode.new('Certificate Validations', @content[:IM4M].validate.map { |v|
            Helpers::TreeNode.new(v.ai)
          })
        end

        # Converts the IMG4 file structure into a tree for visualization.
        #
        # @return [Helpers::TreeNode] The root node of the tree.
        def to_tree
          node = Helpers::TreeNode.new(Models::IMG4.key_name(:IMG4))
          @content.each_value { |value| node.children << value.to_tree }
          to_tree_hashes(node)
          to_tree_validations(node)

          node
        end

        # Retrieves the IM4M manifest component.
        #
        # @return [IMG4Manifest, nil] The manifest object if present.
        def manifest
          @content[:IM4M]
        end

        # Retrieves the type of the IM4P payload.
        #
        # @return [Symbol, nil] The payload type (e.g., :ibot).
        def payload_type
          @content[:IM4P]&.type&.to_sym
        end

        # Retrieves the type of the IM4M manifest.
        #
        # @return [Symbol, nil] The manifest type.
        def manifest_type
          @content[:IM4M]&.type&.to_sym
        end

        # Initializes a new IMG4 file from DER-encoded data.
        #
        # @param der [String, Models::Digest] The raw DER data or a Digest object containing it.
        # @param filename [String, nil] The optional filename for reference.
        def initialize(der, filename = nil)
          MooTool::Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
          @filename = filename

          raw_data = der.is_a?(MooTool::Models::Digest) ? der.value : der

          @hash_data = [{ kind: :'file:hash', value: raw_data }]
          @data = OpenSSL::ASN1.decode(raw_data)
          @type = @data.value[0].value
          @content = {}
          parse
        end

        # Returns the leaf certificate from the validated chain.
        #
        # @return [OpenSSL::X509::Certificate, nil] The leaf certificate.
        def validated_certificate_chain
          @content[:IM4M].certificates.last
        end

        # Converts the file object and its components into a hash.
        #
        # @return [Hash] A hash representation of the IMG4 file.
        def to_h
          result = @content.dup
          result[:comb] = @content[:comb].transform_values(&:to_h) if result[:comb]
          result[:hashes] = named_hashes
          result[:validation] = validate_signature
          result[:certificate_validation] = @certificate_validation
          result.deep_symbolize_keys
        end

        # Computes the SHA-384 hash of the file.
        #
        # @return [String] The hex-encoded hash string.
        def file_hash
          named_hashes[:'file:hash'].shasum
        end

        # Lists all payload types present in the file.
        #
        # @return [Array<Symbol>] An array of payload type symbols.
        def types
          result = [payload_type]
          result += @content[:comb].keys if @content[:comb]
          result += @content[:secb].keys if @content[:secb]
          result.compact.map(&:to_sym)
        end

        # Retrieves the raw payload data from the IM4P component.
        #
        # @return [String, nil] The raw payload bytes.
        def payload
          @content[:IM4P]&.payload
        end

        # Checks if an IM4P payload is present.
        #
        # @return [Boolean] True if a payload exists.
        def payload?
          !@content[:IM4P].nil?
        end

        # Checks if an IM4M manifest is present.
        #
        # @return [Boolean] True if a manifest exists.
        def manifest?
          !@content[:IM4M].nil?
        end

        # Generates a basename for the file based on its type.
        #
        # @return [String] The basename with an appropriate extension.
        def basename
          basename = ::File.basename(@filename)
          extension = ::File.extname(basename)
          "#{basename.chomp(extension)}.#{@type}"
        end

        # Extracts the payload and writes it to disk.
        #
        # @return [void]
        def extract_payload
          output_path = ::File.join(::File.dirname(@filename), basename)
          ::File.write(output_path, @payload)
        end

        # Generates SHA-384 digests for all hashes in the file.
        #
        # @return [Array<Models::Digest>] An array of Digest objects.
        def hashes
          raw_hashes.map do |hash_pair|
            hash_kind = hash_pair[:kind]
            hash = hash_pair[:value]
            Models::Digest.new(::Digest::SHA384.digest(hash), hash_kind)
          end
        end

        # Collects raw hashes from all internal components.
        #
        # @param prefix [String, nil] An optional prefix for the hash kinds.
        # @return [Array<Hash>] An array of hash entries with :kind and :value.
        def raw_hashes(prefix = nil)
          results = @hash_data.dup
          results += @content[:IM4M].raw_hashes if @content[:IM4M]
          results += @content[:IM4P].raw_hashes if @content[:IM4P]
          results += @content[:secb].raw_hashes if @content[:secb]
          results += @content[:comb].raw_hashes if @content[:comb]

          if prefix
            results = results.map do |entry|
              entry[:kind] = :"#{prefix}:#{entry[:kind]}"
              entry
            end
          end

          results.compact.uniq
        end

        # Aggregates public keys from all components.
        #
        # @return [Hash] A map of public keys.
        def public_keys
          results = {}
          results.merge! @content[:IM4M]&.public_keys if @content[:IM4M]
          results.merge! @content[:secb]&.public_keys if @content[:secb]
          results.merge! @content[:comb]&.public_keys if @content[:comb]

          results
        end

        # Prints the file structure to standard output.
        #
        # @return [void]
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
