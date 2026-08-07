# frozen_string_literal: true

require 'spec_helper'
require 'openssl'

RSpec.describe 'OpenSSL::ASN1::ASN1Data extensions' do
  describe '#private_tag?' do
    it 'returns true for PRIVATE tag class' do
      node = OpenSSL::ASN1::ASN1Data.new('data', 0x494D3450, :PRIVATE)
      expect(node.private_tag?).to be true
    end

    it 'returns false for UNIVERSAL tag class' do
      node = OpenSSL::ASN1::Integer.new(42)
      expect(node.private_tag?).to be false
    end
  end

  describe '#context_specific?' do
    it 'returns true for CONTEXT_SPECIFIC tag class' do
      node = OpenSSL::ASN1::ASN1Data.new('data', 0, :CONTEXT_SPECIFIC)
      expect(node.context_specific?).to be true
    end

    it 'returns false for UNIVERSAL tag class' do
      node = OpenSSL::ASN1::Integer.new(42)
      expect(node.context_specific?).to be false
    end
  end

  describe '#universal?' do
    it 'returns true for UNIVERSAL tag class' do
      node = OpenSSL::ASN1::Integer.new(42)
      expect(node.universal?).to be true
    end

    it 'returns false for PRIVATE tag class' do
      node = OpenSSL::ASN1::ASN1Data.new('data', 0x494D3450, :PRIVATE)
      expect(node.universal?).to be false
    end
  end

  describe '#constructive?' do
    it 'returns true for Sequence' do
      node = OpenSSL::ASN1::Sequence.new([])
      expect(node.constructive?).to be true
    end

    it 'returns true for Set' do
      node = OpenSSL::ASN1::Set.new([])
      expect(node.constructive?).to be true
    end

    it 'returns false for Integer' do
      node = OpenSSL::ASN1::Integer.new(42)
      expect(node.constructive?).to be false
    end
  end

  describe '#tag_label' do
    it 'returns 4CC symbol for PRIVATE tag' do
      node = OpenSSL::ASN1::ASN1Data.new('data', 0x494D3450, :PRIVATE)
      label = node.tag_label
      expect(label).to be_a(Symbol)
    end

    it 'returns raw tag for UNIVERSAL' do
      node = OpenSSL::ASN1::Integer.new(42)
      expect(node.tag_label).to eq(OpenSSL::ASN1::INTEGER)
    end
  end
end
