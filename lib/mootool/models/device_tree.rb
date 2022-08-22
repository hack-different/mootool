# frozen_string_literal: true
# typed: true

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
          vals = T.must(data.read(8)).unpack(NODE_FORMAT)
          property_count = T.cast(vals[0], Integer)
          child_count = T.cast(vals[1], Integer)

          @properties = T.let({}, T::Hash[String, Property])
          @children = T.let([], T::Array[Node])

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
          args = T.must(data.read(36)).unpack(PROP_FORMAT)

          @name = T.let(T.cast(args[0], String), String)
          @size = T.let(T.cast(args[1], Integer), Integer)

          if @size & 0x80000000 != 0
            @template = true
            @size &= 0x7fffffff
          end

          @value = data.read(@size.align(4))
          @value = T.must(@value)[0..@size]
        end
      end

      attr_reader :root

      # @param [String] data
      sig { params(data: T.any(IO, String, StringIO, Pathname)).void }
      def initialize(data)
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
        @root = Node.new(@data)
      end

      sig { params(path: String).returns(DeviceTree) }
      def self.open(path)
        DeviceTree.new(Pathname.new(path))
      end
    end
  end
end
