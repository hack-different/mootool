# typed: false
# frozen_string_literal: true

require 'spec_helper'

DEVICE_TREE_D49AP_IM4P = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.d49ap.im4p')

describe MooTool::Models::IMG4::File do
  context 'IM4P device tree' do
  it 'loads an im4p file' do
    file = described_class.load(DEVICE_TREE_D49AP_IM4P)
    expect(file).not_to be_nil
  end

  it 'has a payload the file' do
    file = described_class.load(DEVICE_TREE_D49AP_IM4P)
    expect(file.payload?).to be true
    expect(file.payload).not_to be_nil
  end

  it 'does not have a manifest the file' do
    file = described_class.load(DEVICE_TREE_D49AP_IM4P)
    expect(file.manifest?).to be false
    expect(file.manifest).to be_nil
  end

  it 'does not have a basename the file' do
    file = described_class.load(DEVICE_TREE_D49AP_IM4P)
    file_basename = File.basename(DEVICE_TREE_D49AP_IM4P)

    expect(file.basename.length).to be(file_basename.length)
  end
  end

  context 'with a file index' do
    let(:target_files) do
      index = MooTool::Models::FileIndex.new
      index.perform
      index.index.select { |l| l.img4? }
    end

    it 'should match many files' do
      expect(target_files.size).to be > 200
    end

    it 'should parse all of the files' do
      aggregate_failures do
        target_files.each do |file|
          expect(described_class.load(file)).not_to be_nil
        end
      end
    end
  end
end
