# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    # Represents Apple's I/O Registry, specifically focusing on the device tree and secure boot properties.
    class IOReg
      # Represents a single node in the I/O Registry tree.
      class Node
        # Initializes a new Node instance from a raw node hash.
        #
        # @param node [Hash] The raw node data including children and properties.
        def initialize(node)
          @children = node[:IORegistryEntryChildren] || []
          @name = node[:IORegistryEntryName].to_sym

          node.delete :IORegistryEntryChildren
          node.delete :IORegistryEntryName

          children_nodes = @children.to_h { |child| [child[:IORegistryEntryName].to_sym, Node.new(child)] }
          @properties = node

          @properties.transform_values! do |value|
            case value
            when nil
              nil
            when /([^\0]+)\x00/
              value.strip("\0")
            when CFPropertyList::Blob, String
              value.to_s
            else
              value
            end
          end

          @data = @properties.merge(children_nodes)
        end

        # Accesses a property or child node by key.
        #
        # @param key [Symbol] The property or child name.
        # @return [Object, Node, nil] The value associated with the key.
        def [](key)
          @data[key]
        end

        # Deletes a property or child node by key.
        #
        # @param key [Symbol] The key to delete.
        # @return [Object, nil] The deleted value.
        def delete(key)
          @data.delete(key)
        end

        # Selects elements from the node data.
        #
        # @return [Enumerator, Hash] The selected elements.
        def select(&)
          @data.select(&)
        end

        # Converts the node to a hash.
        #
        # @return [Hash] The hash representation of the node.
        def to_h
          @data
        end

        # Returns a string representation of the node for debugging.
        #
        # @return [String] The inspected hash.
        def inspect
          to_h.ai
        end
      end

      # Transforms a raw node hash into a {Node} instance.
      #
      # @param node [Hash] The raw node data.
      # @return [Node] The transformed node.
      def transform_node(node)
        Node.new node
      end

      # Factory method to create an IOReg instance from a file or by running `ioreg`.
      #
      # @param path [String, nil] Optional path to an XML I/O Registry dump.
      # @return [IOReg] A new IOReg instance.
      def self.create(path = nil)
        if path
          IOReg.new File.read(path)
        else
          IOReg.new `ioreg -a -p IODeviceTree -l`
        end
      end

      # @return [Hash] The collected manifest properties and secure boot hashes.
      attr_reader :manifests

      # The root keys in the device tree where manifest information is found.
      MANIFEST_ROOTS = %i[asmb manifest-properties secure-boot-hashes].freeze

      # Initializes a new IOReg instance from device tree data.
      #
      # @param device_tree_data [String] The XML plist data representing the I/O Registry.
      def initialize(device_tree_data)
        data = CFPropertyList.native_types CFPropertyList::List.new(data: device_tree_data).value
        data = data.deep_symbolize_keys

        @data = transform_node(data)
        @data.delete :IOConsoleUsers
        @data.delete :IOKitDiagnostics

        @entries = @data[:'device-tree'][:chosen]
        @manifests = @entries[:'manifest-properties'].to_h.merge(@entries[:'secure-boot-hashes'].to_h).merge(@entries[:asmb].to_h).transform_values do |v|
          v.is_a?(String) ? v.unpack1('H*').upcase : v
        end
      end

      # Finds properties that match a specific cryptographic hash.
      #
      # @param hash [String] The hex-encoded hash to search for.
      # @return [Array<Symbol>] A list of keys that match the hash.
      def properties_with_hash(hash)
        @manifests.select { |_key, value| value == hash }.map { |k, _v| k }
      end
    end
  end
end
