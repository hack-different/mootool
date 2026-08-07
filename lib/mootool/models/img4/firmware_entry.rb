# frozen_string_literal: true

module MooTool
  module Models::IMG4
    # Represents a structured firmware entry tag, which typically includes a DGST (digest) for the payload.
    class FirmwareEntry < MooTool::Models::IMG4::PropertySequence
      # Initializes a new FirmwareEntry and ensures the 'clas' property matches the firmware type.
      #
      # @param input [OpenSSL::ASN1::Sequence, Hash] The input data for the sequence.
      # @raise [Error] If the 'clas' property is present but does not match the key.
      def initialize(input)
        super
        return unless @value[:clas]
        return if @value[:clas].to_sym == @key

        raise Error,
              'If `clas` is present, it must be a string and match the firmware type'
      end

      # Retrieves the DGST (digest) value for this firmware entry.
      #
      # @return [String, nil] The digest bytes or hex string if present.
      def digest
        @value[:DGST]
      end

      # Converts the firmware entry to a hash representation.
      #
      # @return [Hash] A hash where the key is the human-readable name of the firmware tag.
      def to_h
        { Models::IMG4.key_name(@key) => self }
      end

      # Converts the firmware entry into a tree node for visualization.
      #
      # @return [Helpers::TreeNode] The generated tree node.
      def to_tree
        Helpers::TreeNode.new(ai)
      end
    end
  end
end
