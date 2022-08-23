# frozen_string_literal: true
# typed: true

require 'sorbet-runtime'

module MooTool
  # DeviceTree is a Apple Device Tree node that has been parsed
  class DeviceTree
    extend T::Sig

    NODE_FORMAT = 'VV'
    PROP_FORMAT = 'A32V'

    PHANDLE_PROP = 'AAPL,phandle'
    COMPATIBLE_PROP = 'compatible'

    # Represents a single node in the device tree
    class Node
      extend T::Sig

      attr_reader :children, :properties

      sig { params(tree: DeviceTree, data: T.any(IO, StringIO)).void }
      def initialize(tree, data)
        @tree = tree
        vals = T.must(data.read(8)).unpack(NODE_FORMAT)
        property_count = T.cast(vals[0], Integer)
        child_count = T.cast(vals[1], Integer)

        @properties = T.let({}, T::Hash[String, Property])
        @children = T.let([], T::Array[Node])

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
      extend T::Sig

      attr_accessor :name, :value

      sig { params(data: T.any(StringIO, IO)).void }
      def initialize(data)
        args = T.must(data.read(36)).unpack(PROP_FORMAT)

        @name = T.let(T.cast(args[0], String), String)
        @size = T.let(T.cast(args[1], Integer), Integer)

        if @size & 0x80000000 != 0
          @template = true
          @size &= 0x7fffffff
        end

        @value = T.must(data.read(@size.align(4)))[0..(@size - 1)]

        normalize
      end

      private

      def normalize
        @value = @value.split("\x00").map(&:chomp) if @name == COMPATIBLE_PROP
        @value = @value.unpack1('V') if @size == 4

        @value = @value.chomp("\x00") if @value.is_a?(String) && @value.count("\x00") == 1 && @value.end_with?("\x00")
      end
    end

    attr_reader :root

    # @param [String] data
    sig { params(data: T.any(IO, String, StringIO, Pathname)).void }
    def initialize(data)
      @handles = {}
      case data
      when Pathname
        data = T.assert_type!(data, Pathname)
        @data = File.open(data.realpath, 'rb')
      when String
        data = T.assert_type!(data, String)
        @data = StringIO.new(data)
      when IO
        @data = T.cast(data, IO)
      end
      @root = Node.new(self, @data)
    end

    def add_handle(node, handle)
      @handles[handle] = node
    end

    sig { params(path: String).returns(DeviceTree) }
    def self.open(path)
      MooTool::DeviceTree.new(Pathname.new(path))
    end

    def to_h
      @root.to_h
    end
  end
end
