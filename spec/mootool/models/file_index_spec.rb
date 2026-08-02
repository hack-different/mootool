# frozen_string_literal: true

RSpec.describe MooTool::Models::FileIndex do
  let(:instance) { described_class.new }

  it 'exists with an empty index' do
    expect(instance.index).to be_empty
  end

  describe 'an index that is populated' do
    let(:populated_instance) do
      populated_instance = instance.dup
      populated_instance.perform
      populated_instance
    end

    it 'is populated' do
      expect(populated_instance.index).not_to be_empty
    end

    describe 'with generated hashes' do
      let(:populated_hashes) do
        populated_hashes = populated_instance.dup
        populated_hashes.generate_hashes
        populated_hashes
      end

      it 'is populated with hashes' do
        aggregate_failures do
          expect(populated_hashes.index).not_to be_empty
          expect(populated_hashes.index).to all(be_hashed)
        end
      end
    end
  end
end
