# frozen_string_literal: true

module MooTool
  module Helpers
    # Used in rendering data as a tree of nodes
    class TreeNode
      attr_accessor :name, :children

      def initialize(name, children = [])
        @name = case name
                when Symbol
                  Models::IMG4.key_name(name).ai
                when String
                  name
                else
                  name.ai
                end
        @children = children
      end

      def self.from_h(hash)
        if hash.is_a?(Hash)
          raw_children = hash.key?(:children) ? hash[:children] : []
          children = raw_children.map { |ch| from_h(ch) }
          new hash[:name], children
        else
          new hash
        end
      end

      def self.from_json(json)
        hash = JSON.parse json, symbolize_names: true
        from_h hash
      end

      def to_h
        {
          name: @name,
          children: @children.map(&:to_h)
        }
      end

      def to_json(**)
        JSON.generate(to_h, **)
      end

      def render
        lines = @name.split("\n")
        @children.each_with_index do |child, index|
          child_lines = child.render
          if index < @children.size - 1
            child_lines.each_with_index do |line, idx|
              prefix = idx.zero? ? '├── ' : '|   '
              lines << "#{prefix}#{line}"
            end
          else
            child_lines.each_with_index do |line, idx|
              prefix = idx.zero? ? '└── ' : '    '
              lines << "#{prefix}#{line}"
            end
          end
        end
        lines
      end

      def print(stream: $stdout, prefix: '')
        stream.puts(render.map { |line| "#{prefix}#{line}\n" })
      end
    end
  end
end
