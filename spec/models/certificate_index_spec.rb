# frozen_string_literal: true

RSpec.describe MooTool::Models::CertificateIndex do
  let(:instance) { described_class.new }

  it 'is empty' do
    expect(instance.index).to be_empty
  end

  context 'with a certificate' do
    let(:certificate) { MooTool::Models::Certificate.load(File.join(FIXTURE_PATH, 'dcrt.der')) }
    let(:populated_instance) do
      populated_instance = described_class.new
      populated_instance.add_certificate certificate
      populated_instance
    end

    it 'contains one certificate' do
      expect(populated_instance.index.values).to contain_exactly(certificate)
    end
  end
end
