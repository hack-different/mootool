require 'cfpropertylist'

module MooTool
  module Models
    class IOReg
      def initialize(device_tree_data)
        data = CFPropertyList.native_types CFPropertyList::List.new(data: device_tree_data).value
        data = data.deep_symbolize_keys

        result = {}
        result =  data[:IORegistryEntryChildren].first[:IORegistryEntryChildren].first[:IORegistryEntryChildren].map do |e|
          [e[:IORegistryEntryName], e]
        end.to_h

        @data = result.transform_values do |value|
          value.map do |key, property|
            if property.is_a?(String)
              [key, property.unpack1('H*').upcase]
            else
              [key, property]
            end
          end.to_h
        end
      end

      def properties_with_hash(hash)
        matching = @data['manifest-properties'].select { |key, value| value == hash }.map {|k,v| k}
        matching += @data['secure-boot-hashes'].select { |key, value| value == hash }.map {|k,v| k}
        matching += @data['asmb'].select { |key, value| value == hash }.map {|k,v| k}

        matching
      end
    end
  end
end