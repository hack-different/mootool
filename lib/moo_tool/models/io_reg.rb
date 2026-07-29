# frozen_string_literal: true

require 'cfpropertylist'

module MooTool
  module Models
    class IOReg
      class Node
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

        def [](key)
          @data[key]
        end

        def delete(key)
          @data.delete(key)
        end

        def select(&)
          @data.select(&)
        end

        def to_h
          @data
        end

        def inspect
          to_h.ai
        end
      end

      def transform_node(node)
        Node.new node
      end

      def self.create(path = nil)
        if path
          IOReg.new File.read(path)
        else
          IOReg.new `ioreg -a -p IODeviceTree -l`
        end
      end

      attr_reader :manifests

      MANIFEST_ROOTS = %i[asmb manifest-properties secure-boot-hashes].freeze

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

      def properties_with_hash(hash)
        @manifests.select { |_key, value| value == hash }.map { |k, _v| k }
      end
    end
  end
end
