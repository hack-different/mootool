# typed: false
# frozen_string_literal: true

require 'spec_helper'

# The manifest specification of the issue, as produced by an Apple signing certificate:
#
#   SET (2 elem)
#     Private_1296125520 (MANP) -> SEQUENCE { IA5String MANP, SET { faic, inst } }
#     Private_1329744464 (OBJP) -> SEQUENCE { IA5String OBJP, SET { DGST, inst, prid } }
#
# every leaf being +[PRIVATE <4cc>] SEQUENCE { IA5String <4cc>, [0] NULL }+.
MANIFEST_SPECIFICATION_DER = %w[
  318181FF84EA859C5030302E16044D414E503126FF86B385D2630C300A1604666169
  63A0020500FF86CBB9E6740C300A1604696E7374A0020500FF84FA8994504330411604
  4F424A503139FF84A29DA6540C300A160444475354A0020500FF86CBB9E6740C300A16
  04696E7374A0020500FF8783C9D2640C300A160470726964A0020500
].join.from_hex.freeze

describe MooTool::Schemas::ASN1::ManifestSpecification do
  subject(:specification) { described_class.parse(MANIFEST_SPECIFICATION_DER) }

  context 'with the certificate manifest specification' do
    it 'parses both property groups' do
      expect(specification.four_ccs).to eq(%i[MANP OBJP])
    end

    it 'maps the whole structure to a hash' do
      expect(specification.to_h).to eq(
        MANP: { faic: nil, inst: nil },
        OBJP: { DGST: nil, inst: nil, prid: nil }
      )
    end

    it 'looks a property group up by its four character code' do
      expect(specification[:OBJP].keys).to eq(%i[DGST inst prid])
    end

    it 'keeps the model element accessible by name' do
      expect(specification[:manifest_specification]).to be_a(RASN2::Types::SetOf)
    end

    it 'exposes the private tag of each property group' do
      expect(specification[0]).to be_a(described_class::PropertySetTag)
    end

    it 'repeats the group four character code in the wrapped sequence key' do
      keys = specification.tags.map { |tag| tag.value[:key].value }

      expect(keys).to eq(%w[MANP OBJP])
    end

    it 're-encodes to the very same DER' do
      expect(specification.to_der).to eq(MANIFEST_SPECIFICATION_DER)
    end
  end

  context 'with values other than NULL' do
    let(:der) do
      base = described_class.parse(MANIFEST_SPECIFICATION_DER)
      base.tags.first.value[:properties].value.first.value[:value].value = RASN2::Types::Integer.new(value: 42).to_der
      base.to_der
    end

    it 'decodes any value carried by a property' do
      expect(described_class.parse(der).to_h[:MANP]).to eq(faic: 42, inst: nil)
    end

    it 're-encodes the modified specification' do
      expect(described_class.parse(der).to_der).to eq(der)
    end
  end
end
