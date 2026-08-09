# frozen_string_literal: true

require 'spec_helper'
require 'openssl'
require 'rasn2'

RSpec.describe MooTool::Visitors::ASN1::MappingVisitor do
  subject(:visitor) { described_class.new }

  context 'with OpenSSL nodes' do
    describe 'primitive type mapping' do
      it 'maps Integer to Ruby Integer' do
        node = OpenSSL::ASN1::Integer.new(42)
        expect(visitor.visit(node)).to eq(42)
      end

      it 'maps large Integer (BN) to Ruby Integer' do
        node = OpenSSL::ASN1::Integer.new(2**128)
        expect(visitor.visit(node)).to eq(2**128)
      end

      it 'maps Boolean true' do
        node = OpenSSL::ASN1::Boolean.new(true)
        expect(visitor.visit(node)).to be true
      end

      it 'maps Boolean false' do
        node = OpenSSL::ASN1::Boolean.new(false)
        expect(visitor.visit(node)).to be false
      end

      it 'maps Null to nil' do
        node = OpenSSL::ASN1::Null.new(nil)
        expect(visitor.visit(node)).to be_nil
      end

      it 'maps OctetString to String' do
        node = OpenSSL::ASN1::OctetString.new("\x01\x02\x03")
        result = visitor.visit(node)
        expect(result).to eq("\x01\x02\x03")
        expect(result).to be_a(String)
      end

      it 'maps BitString to String' do
        node = OpenSSL::ASN1::BitString.new("\xFF\x00")
        result = visitor.visit(node)
        expect(result).to be_a(String)
      end

      it 'maps UTF8String to String' do
        node = OpenSSL::ASN1::UTF8String.new('hello')
        expect(visitor.visit(node)).to eq('hello')
      end

      it 'maps IA5String to String' do
        node = OpenSSL::ASN1::IA5String.new('test@example.com')
        expect(visitor.visit(node)).to eq('test@example.com')
      end

      it 'maps PrintableString to String' do
        node = OpenSSL::ASN1::PrintableString.new('US')
        expect(visitor.visit(node)).to eq('US')
      end

      it 'maps ObjectId to String' do
        node = OpenSSL::ASN1::ObjectId.new('2.5.4.3')
        result = visitor.visit(node)
        expect(result).to be_a(String)
      end

      it 'maps UTCTime to Time' do
        time = Time.now.utc
        node = OpenSSL::ASN1::UTCTime.new(time)
        expect(visitor.visit(node)).to be_a(Time)
      end

      it 'maps GeneralizedTime to Time' do
        time = Time.now.utc
        node = OpenSSL::ASN1::GeneralizedTime.new(time)
        expect(visitor.visit(node)).to be_a(Time)
      end
    end

    describe 'constructive type mapping' do
      it 'maps Sequence to Array' do
        seq = OpenSSL::ASN1::Sequence.new([
                                            OpenSSL::ASN1::Integer.new(1),
                                            OpenSSL::ASN1::Integer.new(2)
                                          ])
        result = visitor.visit(seq)
        expect(result).to eq([1, 2])
      end

      it 'maps Set to Array' do
        set = OpenSSL::ASN1::Set.new([
                                       OpenSSL::ASN1::Integer.new(10),
                                       OpenSSL::ASN1::Boolean.new(true)
                                     ])
        result = visitor.visit(set)
        expect(result).to eq([10, true])
      end

      it 'maps nested Sequence' do
        inner = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(99)])
        outer = OpenSSL::ASN1::Sequence.new([inner, OpenSSL::ASN1::Null.new(nil)])
        result = visitor.visit(outer)
        expect(result).to eq([[99], nil])
      end
    end

    describe 'PRIVATE tag mapping' do
      it 'maps PRIVATE tagged node to Hash with tag label' do
        private_node = OpenSSL::ASN1::ASN1Data.new(
          [OpenSSL::ASN1::Integer.new(42)],
          0x494D3450,
          :PRIVATE
        )
        result = visitor.visit(private_node)
        expect(result).to be_a(Hash)
        expect(result.values.first).to eq([42])
      end

      it 'maps PRIVATE node with non-array value' do
        private_node = OpenSSL::ASN1::ASN1Data.new(
          'raw_bytes',
          0x494D3450,
          :PRIVATE
        )
        result = visitor.visit(private_node)
        expect(result).to be_a(Hash)
        expect(result.values.first).to eq('raw_bytes')
      end
    end

    describe 'depth tracking during mapping' do
      it 'resets depth after mapping' do
        seq = OpenSSL::ASN1::Sequence.new([
                                            OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(1)])
                                          ])
        visitor.visit(seq)
        expect(visitor.depth).to eq(0)
      end
    end
  end

  context 'with RASN2 nodes' do
    describe 'primitive type mapping' do
      it 'maps Integer to Ruby Integer' do
        node = RASN2::Types::Integer.new(value: 42)
        expect(visitor.visit(node)).to eq(42)
      end

      it 'maps Boolean true' do
        node = RASN2::Types::Boolean.new(value: true)
        expect(visitor.visit(node)).to be true
      end

      it 'maps Boolean false' do
        node = RASN2::Types::Boolean.new(value: false)
        expect(visitor.visit(node)).to be false
      end

      it 'maps Null to nil' do
        node = RASN2::Types::Null.new
        expect(visitor.visit(node)).to be_nil
      end

      it 'maps OctetString to String' do
        node = RASN2::Types::OctetString.new(value: "\x01\x02\x03")
        result = visitor.visit(node)
        expect(result).to eq("\x01\x02\x03")
        expect(result).to be_a(String)
      end

      it 'maps BitString to String' do
        node = RASN2::Types::BitString.new(value: "\xFF\x00")
        result = visitor.visit(node)
        expect(result).to be_a(String)
      end

      it 'maps Utf8String to String' do
        node = RASN2::Types::Utf8String.new(value: 'hello')
        expect(visitor.visit(node)).to eq('hello')
      end

      it 'maps IA5String to String' do
        node = RASN2::Types::IA5String.new(value: 'test@example.com')
        expect(visitor.visit(node)).to eq('test@example.com')
      end

      it 'maps PrintableString to String' do
        node = RASN2::Types::PrintableString.new(value: 'US')
        expect(visitor.visit(node)).to eq('US')
      end

      it 'maps ObjectId to String' do
        node = RASN2::Types::ObjectId.new(value: '2.5.4.3')
        result = visitor.visit(node)
        expect(result).to eq('2.5.4.3')
      end
    end

    describe 'constructive type mapping' do
      it 'maps Sequence to Array' do
        seq = RASN2::Types::Sequence.new
        seq.value = [
          RASN2::Types::Integer.new(value: 1),
          RASN2::Types::Integer.new(value: 2)
        ]
        result = visitor.visit(seq)
        expect(result).to eq([1, 2])
      end

      it 'maps nested Sequence' do
        inner = RASN2::Types::Sequence.new
        inner.value = [RASN2::Types::Integer.new(value: 99)]
        outer = RASN2::Types::Sequence.new
        outer.value = [inner, RASN2::Types::Null.new]
        result = visitor.visit(outer)
        expect(result).to eq([[99], nil])
      end
    end

    describe 'depth tracking during mapping' do
      it 'resets depth after mapping' do
        inner = RASN2::Types::Sequence.new
        inner.value = [RASN2::Types::Integer.new(value: 1)]
        outer = RASN2::Types::Sequence.new
        outer.value = [inner]
        visitor.visit(outer)
        expect(visitor.depth).to eq(0)
      end
    end
  end
end
