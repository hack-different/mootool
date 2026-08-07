# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MooTool::Visitors::ASN1::Adapters::AdapterBase do
  describe '.wrap' do
    it 'wraps OpenSSL::ASN1 nodes in Openssl adapter' do
      node = OpenSSL::ASN1::Integer.new(42)
      adapter = described_class.wrap(node)
      expect(adapter).to be_a(MooTool::Visitors::ASN1::Adapters::OpenSSLAdapter)
    end

    it 'wraps RASN1::Types nodes in Rasn1 adapter' do
      node = RASN1::Types::Integer.new(value: 42)
      adapter = described_class.wrap(node)
      expect(adapter).to be_a(MooTool::Visitors::ASN1::Adapters::RASN1Adapter)
    end

    it 'raises ArgumentError for unsupported types' do
      expect { described_class.wrap('not an ASN1 node') }.to raise_error(ArgumentError)
    end
  end
end
