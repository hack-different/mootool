# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MooTool::Helpers::LeafNode do
  describe '#initialize' do
    it 'stores a string value' do
      leaf = described_class.new('hello')
      expect(leaf.value).to eq('hello')
    end

    it 'converts non-string values to string' do
      leaf = described_class.new(42)
      expect(leaf.value).to eq('42')
    end

    it 'stores an optional key' do
      leaf = described_class.new('world', key: 'greeting')
      expect(leaf.key).to eq('greeting')
      expect(leaf.value).to eq('world')
    end

    it 'converts symbol keys to string' do
      leaf = described_class.new('val', key: :my_key)
      expect(leaf.key).to eq('my_key')
    end

    it 'has nil key by default' do
      leaf = described_class.new('test')
      expect(leaf.key).to be_nil
    end
  end

  describe '#key_value?' do
    it 'returns true when key is set' do
      leaf = described_class.new('val', key: 'k')
      expect(leaf.key_value?).to be true
    end

    it 'returns false when key is nil' do
      leaf = described_class.new('val')
      expect(leaf.key_value?).to be false
    end
  end

  describe '#render' do
    it 'renders a simple value' do
      leaf = described_class.new('hello')
      expect(leaf.render).to eq(['hello'])
    end

    it 'renders a key/value pair' do
      leaf = described_class.new('world', key: 'greeting')
      expect(leaf.render).to eq(['greeting: world'])
    end

    it 'handles multi-line values' do
      leaf = described_class.new("line1\nline2")
      expect(leaf.render).to eq(%w[line1 line2])
    end
  end

  describe '#to_h' do
    it 'returns hash with value only' do
      leaf = described_class.new('test')
      expect(leaf.to_h).to eq({ value: 'test' })
    end

    it 'includes key when present' do
      leaf = described_class.new('val', key: 'k')
      expect(leaf.to_h).to eq({ value: 'val', key: 'k' })
    end
  end

  describe '#accept' do
    it 'calls visit_leaf on the visitor' do
      leaf = described_class.new('test')
      visitor = MooTool::Helpers::TreeVisitor.new
      result = leaf.accept(visitor)
      expect(result).to eq('test')
    end

    it 'returns key/value hash for key_value leaf' do
      leaf = described_class.new('val', key: 'k')
      visitor = MooTool::Helpers::TreeVisitor.new
      result = leaf.accept(visitor)
      expect(result).to eq({ 'k' => 'val' })
    end
  end

  describe '#print' do
    it 'prints to a stream' do
      leaf = described_class.new('hello')
      output = StringIO.new
      leaf.print(stream: output)
      expect(output.string).to include('hello')
    end
  end
end
