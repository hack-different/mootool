# typed: false
# frozen_string_literal: true

require 'spec_helper'

# +[PRIVATE 'zzzz'] EXPLICIT SEQUENCE { IA5String "zzzz", [0] NULL }+, an Apple shaped tag whose
# four character code is not described anywhere.
UNKNOWN_PRIVATE_TAG_DER = 'FF87D3E9F47A0C300A16047A7A7A7AA0020500'.from_hex.freeze

# +[PRIVATE 'inst'] EXPLICIT SEQUENCE { IA5String "inst", [0] NULL }+.
KNOWN_PRIVATE_TAG_DER = 'FF86CBB9E6740C300A1604696E7374A0020500'.from_hex.freeze

describe MooTool::Schemas::ASN1::PrivateTag do
  context 'with an undescribed four character code' do
    subject(:tag) { described_class.parse(UNKNOWN_PRIVATE_TAG_DER) }

    it 'accepts any private constructed identifier' do
      expect(tag.four_cc).to be(:zzzz)
    end

    it 'reports the raw identifier value' do
      expect(tag.id).to eq('zzzz'.unpack1('N'))
    end

    it 'is a private constructed type' do
      aggregate_failures do
        expect(tag.asn1_class).to be(:private)
        expect(tag).to be_constructed
      end
    end

    it 'keeps the content as ANY' do
      expect(tag.value).to be_a(RASN2::Types::Any)
    end

    it 're-encodes to the very same DER' do
      expect(tag.to_der).to eq(UNKNOWN_PRIVATE_TAG_DER)
    end
  end

  context 'when restricted to a single four character code' do
    it 'parses the expected tag' do
      expect(described_class.parse(KNOWN_PRIVATE_TAG_DER, four_cc: :inst).four_cc).to be(:inst)
    end

    it 'rejects any other tag' do
      expect { described_class.parse(UNKNOWN_PRIVATE_TAG_DER, four_cc: :inst) }
        .to raise_error(RASN2::ASN1Error)
    end

    it 'encodes the identifier of the requested code' do
      tag = described_class.new(four_cc: 'inst', value: RASN2::Types::Null.new)

      expect(tag.to_der).to eq('FF86CBB9E674020500'.from_hex)
    end
  end

  context 'when the identifier is not a private constructed one' do
    it 'raises on a universal type' do
      expect { described_class.parse("\x05\x00") }.to raise_error(RASN2::ASN1Error)
    end

    it 'stays silent when optional' do
      tag = described_class.new(optional: true)
      tag.parse!("\x05\x00")

      expect(tag.value).to be_nil
    end
  end
end
