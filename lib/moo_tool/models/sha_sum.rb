# frozen_string_literal: true

module MooTool
  module Models
    class ShaSum
      attr_reader :index

      delegate :has_key?, to: :index
      def initialize(lines)
        @lines = lines.map(&:split)
        grouped = @lines.group_by do |hash, _file|
          hash
        end
        mapping = grouped.map do |key, values|
          [key.upcase, values.map { |v| Pathname.new v[1] }]
        end
        @index = mapping.to_h
      end

      def self.from_file(file)
        new File.readlines(file)
      end
    end
  end
end
