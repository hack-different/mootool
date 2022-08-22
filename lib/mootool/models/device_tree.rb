# frozen_string_literal: true

require 'sorbet-runtime'

module MooTool
  module Models
    # DeviceTree is a Apple Device Tree node that has been parsed
    class DeviceTree
      extend T::Sig

      NODE_FORMAT = 'VV'
      PROP_FORMAT = 'A32V'

      # Represents a single node in the device tree
      class Node
        extend T::Sig

        attr_reader :children, :properties

        sig { params(data: T.any(IO, StringIO)).void }
        def initialize(data)
          property_count, child_count = data.read(8).unpack(NODE_FORMAT)
          @properties = {}
          @children = []

          property_count.times do
            prop = Property.new(data)
            @properties[prop.name] = prop
          end
          child_count.times { @children << Node.new(data) }
        end
      end

      # Represents a single property and it's value
      class Property
        extend T::Sig

        attr_accessor :name, :value

        sig { params(data: T.any(StringIO, IO)).void }
        def initialize(data)
          header = data.read(36)

          raise  'Unable to read property header' unless header

          @name, @size = header.unpack(PROP_FORMAT)

          if @size & 0x80000000 != 0
            @template = true
            @size &= 0x7fffffff
          end

          @value = data.read(@size.align(4))
          @value = @value[0..@size]
        end
      end

      attr_reader :root

      # @param [String] data
      sig { params(data: T.any(IO, String, Pathname)).void }
      def initialize(data)
        @data = data

        @data = File.open(@data.realpath, 'rb') if @data.is_a?(Pathname)
        @data = StringIO.new(@data) if @data.is_a?(String)

        @root = Node.new(@data)
      end

      sig { params(path: String).returns(DeviceTree) }
      def self.open(path)
        DeviceTree.new(Pathname.new(path))
      end

      private

      def parse
        @children = []
        @total_length = 8
        @property_count, @child_count = data.unpack(NODE_FORMAT)
        data = data[8..]

        (0...@property_count).inject(data) do |data, _|
          parse_property(data)
        end

        @child_count.times { @children << DeviceTreeNode.new(data) }
      end

      sig { params(data: String).returns(String) }
      def parse_property(data)
        key, length = data.unpack(PROP_FORMAT)
        data = data[36..]

        # Indicates that the value is padded out to the next whole int32
        if length & 0x80000000 != 0
          @template = true
          length &= 0x7fffffff
        end

        aligned_length = length.align(4)

        @key = key
        @value = data[0..length - 1]

        @total_length += 32 + 4 + aligned_length

        data[aligned_length..]
      end
    end
  end
end
