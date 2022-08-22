# frozen_string_literal: true

require 'spec_helper'

describe Integer do
  describe '#align' do
    it 'should align to the nearest multiple of 2 alignment' do
      expect(1.align(2)).to eq(2)
      expect(2.align(2)).to eq(2)
      expect(3.align(2)).to eq(4)
      expect(4.align(2)).to eq(4)
      expect(5.align(2)).to eq(6)
      expect(6.align(2)).to eq(6)
      expect(7.align(2)).to eq(8)
      expect(8.align(2)).to eq(8)
    end

    it 'should return the identity when aligning to one' do
      expect(0.align(1)).to eq(0)
      expect(1.align(1)).to eq(1)
      expect(2.align(1)).to eq(2)
      expect(3.align(1)).to eq(3)
      expect(4.align(1)).to eq(4)
      expect(5.align(1)).to eq(5)
      expect(6.align(1)).to eq(6)
      expect(7.align(1)).to eq(7)
      expect(8.align(1)).to eq(8)
    end

    it 'should align to the nearest multiple of 4 alignment' do
      expect(0.align(4)).to eq(0)
      expect(1.align(4)).to eq(4)
      expect(2.align(4)).to eq(4)
      expect(3.align(4)).to eq(4)
      expect(4.align(4)).to eq(4)
      expect(5.align(4)).to eq(8)
      expect(6.align(4)).to eq(8)
      expect(7.align(4)).to eq(8)
      expect(8.align(4)).to eq(8)
    end
  end
end
