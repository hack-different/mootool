# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MooTool::Helpers::TreeNode do
  describe '#initialize' do
    it 'stores a string name' do
      node = described_class.new('Root')
      expect(node.name).to eq('Root')
    end

    it 'defaults to empty children' do
      node = described_class.new('Root')
      expect(node.children).to eq([])
    end

    it 'accepts type, id, and properties' do
      node = described_class.new('MyClass', type: :class, id: 'cls-1', properties: { version: '1.0' })
      expect(node.type).to eq(:class)
      expect(node.id).to eq('cls-1')
      expect(node.properties).to eq({ version: '1.0' })
    end

    it 'defaults type, id, properties to nil/empty' do
      node = described_class.new('Root')
      expect(node.type).to be_nil
      expect(node.id).to be_nil
      expect(node.properties).to eq({})
    end
  end

  describe '#accept' do
    it 'calls visit_tree on the visitor' do
      node = described_class.new('Root')
      visitor = MooTool::Helpers::TreeVisitor.new
      result = node.accept(visitor)
      expect(result).to eq({ name: 'Root', children: [] })
    end
  end

  describe '#to_h' do
    it 'returns basic hash without optional fields' do
      node = described_class.new('Root')
      expect(node.to_h).to eq({ name: 'Root', children: [] })
    end

    it 'includes type, id, and properties when present' do
      node = described_class.new('Node', type: :class, id: 'n1', properties: { foo: 'bar' })
      h = node.to_h
      expect(h[:type]).to eq(:class)
      expect(h[:id]).to eq('n1')
      expect(h[:properties]).to eq({ foo: 'bar' })
    end

    it 'serializes children recursively' do
      leaf = MooTool::Helpers::LeafNode.new('child_val')
      node = described_class.new('Parent', [leaf])
      h = node.to_h
      expect(h[:children]).to eq([{ value: 'child_val' }])
    end
  end

  describe '.from_h' do
    it 'creates a TreeNode from a hash' do
      hash = { name: 'Root', children: [{ name: 'Child', children: [] }] }
      node = described_class.from_h(hash)
      expect(node).to be_a(described_class)
      expect(node.name).to eq('Root')
      expect(node.children.size).to eq(1)
      expect(node.children.first.name).to eq('Child')
    end

    it 'creates a LeafNode from a hash with :value key' do
      hash = { value: 'leaf_val', key: 'k' }
      result = described_class.from_h(hash)
      expect(result).to be_a(MooTool::Helpers::LeafNode)
      expect(result.value).to eq('leaf_val')
      expect(result.key).to eq('k')
    end

    it 'creates a LeafNode from a non-hash value' do
      result = described_class.from_h('simple')
      expect(result).to be_a(MooTool::Helpers::LeafNode)
      expect(result.value).to eq('simple')
    end

    it 'restores type, id, and properties' do
      hash = { name: 'N', type: :module, id: 'x', properties: { a: 1 }, children: [] }
      node = described_class.from_h(hash)
      expect(node.type).to eq(:module)
      expect(node.id).to eq('x')
      expect(node.properties).to eq({ a: 1 })
    end
  end

  describe '#render' do
    it 'renders a simple tree' do
      child1 = described_class.new('Child1')
      child2 = described_class.new('Child2')
      root = described_class.new('Root', [child1, child2])
      lines = root.render
      expect(lines[0]).to eq('Root')
      expect(lines[1]).to eq('├───◦ Child1')
      expect(lines[2]).to eq('└───◦ Child2')
    end

    it 'renders type and id in header' do
      node = described_class.new('MyNode', type: :class, id: 'abc')
      lines = node.render
      expect(lines[0]).to eq("class @ \e[1;33m\"abc\"\e[0m")
    end

    it 'renders properties in header' do
      node = described_class.new('Node', properties: { 'version' => '1.0', 'author' => 'test' })
      lines = node.render
      expect(lines[0]).to eq('Node')
      expect(lines[1]).to eq("│   \e[1;33m\"version\"\e[0m => \e[1;33m\"1.0\"\e[0m")
      expect(lines[2]).to eq("│   \e[1;33m\"author\"\e[0m => \e[1;33m\"test\"\e[0m")
    end

    it 'renders LeafNode children correctly' do
      leaf = MooTool::Helpers::LeafNode.new('leaf_value')
      root = described_class.new('Root', [leaf])
      lines = root.render
      expect(lines[0]).to eq('Root')
      expect(lines[1]).to eq('└───◦ leaf_value')
    end

    it 'handles multi-line leaf values with proper continuation' do
      leaf = MooTool::Helpers::LeafNode.new("line1\nline2")
      child2 = described_class.new('After')
      root = described_class.new('Root', [leaf, child2])
      lines = root.render
      expect(lines[0]).to eq('Root')
      expect(lines[1]).to eq('├───◦ line1')
      expect(lines[2]).to eq('│   line2')
      expect(lines[3]).to eq('└───◦ After')
    end

    it 'handles multi-line leaf as last child' do
      leaf = MooTool::Helpers::LeafNode.new("line1\nline2")
      root = described_class.new('Root', [leaf])
      lines = root.render
      expect(lines[0]).to eq('Root')
      expect(lines[1]).to eq('└───◦ line1')
      expect(lines[2]).to eq('    line2')
    end

    it 'renders nested trees' do
      grandchild = described_class.new('GrandChild')
      child = described_class.new('Child', [grandchild])
      root = described_class.new('Root', [child])
      lines = root.render
      expect(lines[0]).to eq('Root')
      expect(lines[1]).to eq('└───◦ Child')
      expect(lines[2]).to eq('    └───◦ GrandChild')
    end
  end

  describe '#print' do
    it 'prints to a stream with prefix' do
      node = described_class.new('Root', [described_class.new('Child')])
      output = StringIO.new
      node.print(stream: output, prefix: '>> ')
      expect(output.string).to include('>> Root')
      expect(output.string).to include('>> └───◦ Child')
    end
  end
end

RSpec.describe MooTool::Helpers::TreeVisitor do
  let(:visitor) { described_class.new }

  describe '#initialize' do
    it 'starts at depth 0' do
      expect(visitor.depth).to eq(0)
    end

    it 'has empty parents' do
      expect(visitor.parents).to be_empty
    end
  end

  describe '#root?' do
    it 'is true at initialization' do
      expect(visitor.root?).to be true
    end
  end

  describe '#parent' do
    it 'is nil at root' do
      expect(visitor.parent).to be_nil
    end
  end

  describe '#visit_leaf' do
    it 'returns the leaf value for simple leaves' do
      leaf = MooTool::Helpers::LeafNode.new('test')
      expect(visitor.visit_leaf(leaf)).to eq('test')
    end

    it 'returns key/value hash for key_value leaves' do
      leaf = MooTool::Helpers::LeafNode.new('val', key: 'k')
      expect(visitor.visit_leaf(leaf)).to eq({ 'k' => 'val' })
    end
  end

  describe '#visit_tree' do
    it 'returns name and empty children for childless node' do
      node = MooTool::Helpers::TreeNode.new('Root')
      result = visitor.visit_tree(node)
      expect(result).to eq({ name: 'Root', children: [] })
    end

    it 'recursively visits children' do
      leaf = MooTool::Helpers::LeafNode.new('val')
      child = MooTool::Helpers::TreeNode.new('Child', [leaf])
      root = MooTool::Helpers::TreeNode.new('Root', [child])

      result = visitor.visit_tree(root)
      expect(result[:name]).to eq('Root')
      expect(result[:children].size).to eq(1)
      expect(result[:children][0][:name]).to eq('Child')
      expect(result[:children][0][:children]).to eq(['val'])
    end
  end

  describe 'depth and parent tracking' do
    let(:tracking_visitor_class) do
      Class.new(described_class) do
        attr_reader :max_depth, :recorded_parents

        def initialize
          super
          @max_depth = 0
          @recorded_parents = []
        end

        def visit_leaf(leaf)
          @max_depth = depth if depth > @max_depth
          @recorded_parents = parents.map(&:name)
          super
        end
      end
    end

    it 'tracks depth through nested structures' do
      leaf = MooTool::Helpers::LeafNode.new('deep')
      mid = MooTool::Helpers::TreeNode.new('Mid', [leaf])
      root = MooTool::Helpers::TreeNode.new('Root', [mid])

      tv = tracking_visitor_class.new
      root.accept(tv)
      expect(tv.max_depth).to eq(2)
    end

    it 'tracks parent chain' do
      leaf = MooTool::Helpers::LeafNode.new('deep')
      mid = MooTool::Helpers::TreeNode.new('Mid', [leaf])
      root = MooTool::Helpers::TreeNode.new('Root', [mid])

      tv = tracking_visitor_class.new
      root.accept(tv)
      expect(tv.recorded_parents).to eq(%w[Root Mid])
    end

    it 'resets depth after visiting' do
      leaf = MooTool::Helpers::LeafNode.new('val')
      root = MooTool::Helpers::TreeNode.new('Root', [leaf])

      tv = tracking_visitor_class.new
      root.accept(tv)
      expect(tv.depth).to eq(0)
      expect(tv.parents).to be_empty
    end
  end

  describe 'custom visitor subclass' do
    let(:leaf_collector_class) do
      Class.new(described_class) do
        def visit_leaf(leaf)
          leaf.value
        end

        def visit_tree(node)
          visit_children(node).flatten
        end
      end
    end

    it 'collects all leaf values' do
      leaf1 = MooTool::Helpers::LeafNode.new('a')
      leaf2 = MooTool::Helpers::LeafNode.new('b')
      child = MooTool::Helpers::TreeNode.new('Child', [leaf2])
      root = MooTool::Helpers::TreeNode.new('Root', [leaf1, child])

      collector = leaf_collector_class.new
      result = root.accept(collector)
      expect(result).to eq(%w[a b])
    end
  end
end
