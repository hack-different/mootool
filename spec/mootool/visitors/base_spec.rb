# frozen_string_literal: true

require 'spec_helper'
require 'openssl'
require 'rasn2'

RSpec.describe MooTool::Visitors::ASN1::VisitorBase do
  subject(:visitor) { described_class.new }

  context 'with OpenSSL nodes' do
    describe '#visit with a primitive node' do
      let(:node) { OpenSSL::ASN1::Integer.new(42) }

      it 'returns the underlying node' do
        result = visitor.visit(node)
        expect(result).to eq(node)
      end

      it 'stays at depth 0' do
        visitor.visit(node)
        expect(visitor.depth).to eq(0)
      end

      it 'has no parents' do
        visitor.visit(node)
        expect(visitor.parents).to be_empty
      end
    end

    describe '#visit with a constructive node' do
      let(:child1) { OpenSSL::ASN1::Integer.new(1) }
      let(:child2) { OpenSSL::ASN1::Integer.new(2) }
      let(:sequence) { OpenSSL::ASN1::Sequence.new([child1, child2]) }

      it 'returns an array of visited children' do
        result = visitor.visit(sequence)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end

      it 'resets depth after visiting' do
        visitor.visit(sequence)
        expect(visitor.depth).to eq(0)
      end

      it 'resets parents after visiting' do
        visitor.visit(sequence)
        expect(visitor.parents).to be_empty
      end
    end

    describe '#visit with nested constructive nodes' do
      let(:inner_child) { OpenSSL::ASN1::Integer.new(99) }
      let(:inner_seq) { OpenSSL::ASN1::Sequence.new([inner_child]) }
      let(:outer_seq) { OpenSSL::ASN1::Sequence.new([inner_seq]) }

      it 'recurses into nested sequences' do
        result = visitor.visit(outer_seq)
        expect(result).to eq([[inner_child]])
      end

      it 'resets depth after nested visit' do
        visitor.visit(outer_seq)
        expect(visitor.depth).to eq(0)
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

          protected

          def visit_primitive(adapter)
            @max_depth = depth if depth > @max_depth
            @recorded_parents = parents.dup
            super
          end
        end
      end

      it 'tracks depth through nested structures' do
        inner = OpenSSL::ASN1::Integer.new(1)
        mid = OpenSSL::ASN1::Sequence.new([inner])
        outer = OpenSSL::ASN1::Sequence.new([mid])

        tv = tracking_visitor_class.new
        tv.visit(outer)
        expect(tv.max_depth).to eq(2)
      end

      it 'tracks parent chain' do
        inner = OpenSSL::ASN1::Integer.new(1)
        mid = OpenSSL::ASN1::Sequence.new([inner])
        outer = OpenSSL::ASN1::Sequence.new([mid])

        tv = tracking_visitor_class.new
        tv.visit(outer)
        expect(tv.recorded_parents.size).to eq(2)
      end
    end

    describe 'PRIVATE tag handling' do
      let(:private_node) do
        OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::Integer.new(42)],
          0x494D3450, # IM4P as integer
          :PRIVATE
        )
      end

      it 'visits PRIVATE tagged nodes' do
        result = visitor.visit(private_node)
        expect(result).to be_an(Array)
      end
    end

    describe 'reduce support' do
      let(:summing_visitor_class) do
        Class.new(described_class) do
          protected

          def visit_primitive(adapter)
            val = adapter.native_value
            val.is_a?(OpenSSL::BN) ? val.to_i : val
          end

          def visit_constructive(_adapter, children)
            children
          end

          def reduce(results)
            results.flatten
          end
        end
      end

      it 'applies reduce to children' do
        child1 = OpenSSL::ASN1::Integer.new(10)
        child2 = OpenSSL::ASN1::Integer.new(20)
        seq = OpenSSL::ASN1::Sequence.new([child1, child2])

        sv = summing_visitor_class.new
        result = sv.visit(seq)
        expect(result).to eq([10, 20])
      end
    end

    describe 'Set handling' do
      let(:child1) { OpenSSL::ASN1::Integer.new(1) }
      let(:child2) { OpenSSL::ASN1::Integer.new(2) }
      let(:set_node) { OpenSSL::ASN1::Set.new([child1, child2]) }

      it 'recurses into Set nodes' do
        result = visitor.visit(set_node)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end
    end
  end

  context 'with RASN2 nodes' do
    describe '#visit with a primitive node' do
      let(:node) { RASN2::Types::Integer.new(value: 42) }

      it 'returns the underlying node' do
        result = visitor.visit(node)
        expect(result).to eq(node)
      end

      it 'stays at depth 0' do
        visitor.visit(node)
        expect(visitor.depth).to eq(0)
      end

      it 'has no parents' do
        visitor.visit(node)
        expect(visitor.parents).to be_empty
      end
    end

    describe '#visit with a constructive node' do
      let(:child1) { RASN2::Types::Integer.new(value: 1) }
      let(:child2) { RASN2::Types::Integer.new(value: 2) }
      let(:sequence) do
        seq = RASN2::Types::Sequence.new
        seq.value = [child1, child2]
        seq
      end

      it 'returns an array of visited children' do
        result = visitor.visit(sequence)
        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end

      it 'resets depth after visiting' do
        visitor.visit(sequence)
        expect(visitor.depth).to eq(0)
      end

      it 'resets parents after visiting' do
        visitor.visit(sequence)
        expect(visitor.parents).to be_empty
      end
    end

    describe '#visit with nested constructive nodes' do
      let(:inner_child) { RASN2::Types::Integer.new(value: 99) }
      let(:inner_seq) do
        seq = RASN2::Types::Sequence.new
        seq.value = [inner_child]
        seq
      end
      let(:outer_seq) do
        seq = RASN2::Types::Sequence.new
        seq.value = [inner_seq]
        seq
      end

      it 'recurses into nested sequences' do
        result = visitor.visit(outer_seq)
        expect(result).to eq([[inner_child]])
      end

      it 'resets depth after nested visit' do
        visitor.visit(outer_seq)
        expect(visitor.depth).to eq(0)
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

          protected

          def visit_primitive(adapter)
            @max_depth = depth if depth > @max_depth
            @recorded_parents = parents.dup
            super
          end
        end
      end

      it 'tracks depth through nested structures' do
        inner = RASN2::Types::Integer.new(value: 1)
        mid = RASN2::Types::Sequence.new
        mid.value = [inner]
        outer = RASN2::Types::Sequence.new
        outer.value = [mid]

        tv = tracking_visitor_class.new
        tv.visit(outer)
        expect(tv.max_depth).to eq(2)
      end

      it 'tracks parent chain' do
        inner = RASN2::Types::Integer.new(value: 1)
        mid = RASN2::Types::Sequence.new
        mid.value = [inner]
        outer = RASN2::Types::Sequence.new
        outer.value = [mid]

        tv = tracking_visitor_class.new
        tv.visit(outer)
        expect(tv.recorded_parents.size).to eq(2)
      end
    end
  end

  describe '#visit with nil' do
    it 'returns nil' do
      expect(visitor.visit(nil)).to be_nil
    end
  end

  describe '#root?' do
    it 'is true before visiting' do
      expect(visitor.root?).to be true
    end
  end
end
