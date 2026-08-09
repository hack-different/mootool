# frozen_string_literal: true

require 'spec_helper'
require 'openssl'
require 'rasn2'

RSpec.describe MooTool::Visitors::ASN1::ValidationVisitor do
  context 'with OpenSSL nodes' do
    describe 'without schema' do
      subject(:visitor) { described_class.new }

      it 'validates any primitive node' do
        node = OpenSSL::ASN1::Integer.new(42)
        expect(visitor.validate(node)).to be true
      end

      it 'validates any constructive node' do
        seq = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(1)])
        expect(visitor.validate(seq)).to be true
      end

      it 'validates PRIVATE tagged nodes' do
        private_node = OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::Integer.new(42)],
          0x494D3450,
          :PRIVATE
        )
        expect(visitor.validate(private_node)).to be true
      end

      it 'has no errors' do
        node = OpenSSL::ASN1::Integer.new(42)
        visitor.validate(node)
        expect(visitor.errors).to be_empty
      end
    end

    describe 'with RASN2 schema' do
      it 'validates matching integer type' do
        schema = RASN2::Types::Integer.new
        node = OpenSSL::ASN1::Integer.new(42)
        visitor = described_class.new(schema)
        expect(visitor.validate(node)).to be true
      end

      it 'validates matching boolean type' do
        schema = RASN2::Types::Boolean.new
        node = OpenSSL::ASN1::Boolean.new(true)
        visitor = described_class.new(schema)
        expect(visitor.validate(node)).to be true
      end

      it 'detects type mismatch' do
        schema = RASN2::Types::Integer.new
        node = OpenSSL::ASN1::Boolean.new(true)
        visitor = described_class.new(schema)
        visitor.validate(node)
        expect(visitor.valid?).to be false
        expect(visitor.errors).not_to be_empty
      end
    end

    describe 'nested validation' do
      it 'validates nested structures' do
        seq = OpenSSL::ASN1::Sequence.new([
                                            OpenSSL::ASN1::Integer.new(1),
                                            OpenSSL::ASN1::Boolean.new(true)
                                          ])
        visitor = described_class.new
        expect(visitor.validate(seq)).to be true
      end
    end

    describe 'PRIVATE tag validation' do
      it 'validates PRIVATE nodes with array values' do
        private_node = OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(1)])],
          0x494D3450,
          :PRIVATE
        )
        visitor = described_class.new
        expect(visitor.validate(private_node)).to be true
      end

      it 'validates PRIVATE nodes with scalar values' do
        private_node = OpenSSL::ASN1::ASN1Data.new(
          'raw',
          0x494D3450,
          :PRIVATE
        )
        visitor = described_class.new
        expect(visitor.validate(private_node)).to be true
      end
    end
  end

  context 'with RASN2 nodes' do
    describe 'without schema' do
      subject(:visitor) { described_class.new }

      it 'validates any primitive node' do
        node = RASN2::Types::Integer.new(value: 42)
        expect(visitor.validate(node)).to be true
      end

      it 'validates any constructive node' do
        seq = RASN2::Types::Sequence.new
        seq.value = [RASN2::Types::Integer.new(value: 1)]
        expect(visitor.validate(seq)).to be true
      end

      it 'has no errors' do
        node = RASN2::Types::Integer.new(value: 42)
        visitor.validate(node)
        expect(visitor.errors).to be_empty
      end
    end

    describe 'with RASN2 schema' do
      it 'validates matching integer type' do
        schema = RASN2::Types::Integer.new
        node = RASN2::Types::Integer.new(value: 42)
        visitor = described_class.new(schema)
        expect(visitor.validate(node)).to be true
      end

      it 'validates matching boolean type' do
        schema = RASN2::Types::Boolean.new
        node = RASN2::Types::Boolean.new(value: true)
        visitor = described_class.new(schema)
        expect(visitor.validate(node)).to be true
      end

      it 'detects type mismatch' do
        schema = RASN2::Types::Integer.new
        node = RASN2::Types::Boolean.new(value: true)
        visitor = described_class.new(schema)
        visitor.validate(node)
        expect(visitor.valid?).to be false
        expect(visitor.errors).not_to be_empty
      end
    end

    describe 'nested validation' do
      it 'validates nested structures' do
        seq = RASN2::Types::Sequence.new
        seq.value = [
          RASN2::Types::Integer.new(value: 1),
          RASN2::Types::Boolean.new(value: true)
        ]
        visitor = described_class.new
        expect(visitor.validate(seq)).to be true
      end
    end
  end

  describe '#valid? and #errors' do
    it 'starts valid' do
      visitor = described_class.new
      expect(visitor.valid?).to be true
      expect(visitor.errors).to eq([])
    end
  end
end
