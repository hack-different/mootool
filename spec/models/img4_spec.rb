# typed: false
# frozen_string_literal: true

require 'spec_helper'

DEVICE_TREE_D49AP_IM4P = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.d49ap.im4p')

describe MooTool::IMG4::File do
  it 'loads an im4p file' do
    file = described_class.new(DEVICE_TREE_D49AP_IM4P)
    expect(file).not_to be_nil
  end

  it 'has a payload the file' do
    file = described_class.new(DEVICE_TREE_D49AP_IM4P)
    expect(file.payload?).to be true
    expect(file.payload).not_to be_nil
  end

  it 'does not have a manifest the file' do
    file = described_class.new(DEVICE_TREE_D49AP_IM4P)
    expect(file.manifest?).to be false
    expect(file.manifest).to be_nil
  end

  it 'does not have a basename the file' do
    file = described_class.new(DEVICE_TREE_D49AP_IM4P)
    file_basename = File.basename(DEVICE_TREE_D49AP_IM4P)

    expect(file.basename.length).to be(file_basename.length)
  end
end
