# frozen_string_literal: true
# typed: true

module MooTool
  module Models
    # DeviceTree is a bianry version of the device tree loaded by iBoot
    class DeviceTree
      NODE_FORMAT = 'VV'
      PROP_FORMAT = 'A32V'

      PHANDLE_PROP = 'AAPL,phandle'
      COMPATIBLE_PROP = 'compatible'

      # Represents a single node in the device tree
      class Node
        attr_reader :children, :properties

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

        def to_h
          props = @properties.transform_values(&:value)
          if @children.any?
            props.merge({ children: @children.map(&:to_h) })
          else
            props
          end
        end
      end

      # Represents a single property and it's value
      class Property
        attr_accessor :name, :value

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

      attr_reader :root

      # @param [String] data
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

      def add_handle(node, handle)
        @handles[handle] = node
      end

      def self.load(path)
        MooTool::Models::DeviceTree.new(Pathname.new(path))
      end

      def to_h
        @root.to_h
      end
    end
  end
end
