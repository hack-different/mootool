# frozen_string_literal: true
# typed: true

module MooTool
  module Models
    # DeviceTree represents a binary device tree (dtb) loaded by Apple's iBoot
    class DeviceTree
      # Format for node header: property count (V), child count (V)
      NODE_FORMAT = 'VV'
      # Format for property: name (A32), size (V)
      PROP_FORMAT = 'A32V'

      # Property name for handle
      PHANDLE_PROP = 'AAPL,phandle'
      # Property name for compatible string
      COMPATIBLE_PROP = 'compatible'

      # Represents a single node in the device tree
      class Node
        # @return [Array<Node>] The child nodes of this node.
        attr_reader :children
        # @return [Hash{String => Property}] The properties of this node.
        attr_reader :properties

        # Initializes a new Node from binary data
        #
        # @param tree [DeviceTree] The parent device tree.
        # @param data [IO, StringIO] The binary data stream.
        def initialize(tree, data)
          @tree = tree
          vals = data.read(8).unpack(NODE_FORMAT)
          property_count = vals[0]
          child_count = vals[1]

          @properties = {}
          @children = []

          property_count.times do
            prop = Property.new(data)
            @properties[prop.name] = prop
          end
          child_count.times { @children << Node.new(tree, data) }

          @tree.add_handle(self, @properties[PHANDLE_PROP].value) if @properties.key? PHANDLE_PROP
        end

        # Converts the node and its children to a Hash representation
        #
        # @return [Hash]
        def to_h
          props = @properties.transform_values(&:value)
          if @children.any?
            props.merge({ children: @children.map(&:to_h) })
          else
            props
          end
        end
      end

      # Represents a single property and its value within a device tree node
      class Property
        # @return [String] The name of the property.
        attr_accessor :name
        # @return [Object] The normalized value of the property.
        attr_accessor :value

        # Initializes a new Property from binary data
        #
        # @param data [IO, StringIO] The binary data stream.
        def initialize(data)
          args = data.read(36).unpack(PROP_FORMAT)

          @name = args[0]
          @size = args[1]

          if @size & 0x80000000 != 0
            @template = true
            @size &= 0x7fffffff
          end

          @value = data.read(@size.align(4))[0..(@size - 1)]

          normalize
        end

        private

        def normalize
          @value = @value.split("\x00").map(&:chomp) if @name == COMPATIBLE_PROP
          @value = @value.unpack1('V') if @size == 4 && @value.is_a?(String)
          @value = @value.unpack1('Q') if @size == 8 && @value.is_a?(String)

          @value = @value.chomp("\x00") if @value.is_a?(String) && @value.count("\x00") == 1 && @value.end_with?("\x00")
          @value = @value.force_encoding('ASCII-8BIT') if @value.is_a?(String)
        end
      end

      # @return [Node] The root node of the device tree.
      attr_reader :root

      # Initializes a new DeviceTree from various data sources
      #
      # @param data [String, Pathname, IO, MooTool::Models::Decompressor] The device tree data.
      def initialize(data)
        @handles = {}
        case data
        when Pathname
          @data = File.open(data.realpath, 'rb')
        when String
          @data = StringIO.new(data)
        when IO
          @data = data
        when MooTool::Models::Decompressor
          @data = StringIO.new data.data
        end
        @root = Node.new(self, @data)
      end

      # Registers a node handle for lookup
      #
      # @param node [Node] The node to register.
      # @param handle [Integer] The phandle value.
      # @return [void]
      def add_handle(node, handle)
        @handles[handle] = node
      end

      # Loads a device tree from a file
      #
      # @param path [String, Pathname] Path to the binary device tree file.
      # @return [DeviceTree]
      def self.load(path)
        MooTool::Models::DeviceTree.new(Pathname.new(path))
      end

      # Converts the device tree to a Hash representation
      #
      # @return [Hash]
      def to_h
        @root.to_h
      end
    end
  end
end
