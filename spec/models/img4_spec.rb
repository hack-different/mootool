# typed: false
# frozen_string_literal: true

require 'spec_helper'

DEVICE_TREE_D49AP_IM4P = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.d49ap.im4p')

describe MooTool::Img4::File do
  it 'should load an im4p file' do
    file = MooTool::Img4::File.new(DEVICE_TREE_D49AP_IM4P)
    expect(file).to_not be_nil
  end

  it 'should have a payload the file' do
    file = MooTool::Img4::File.new(DEVICE_TREE_D49AP_IM4P)
    expect(file.payload?).to be true
    expect(file.payload).to_not be_nil
  end

  it 'should not have a manifest the file' do
    file = MooTool::Img4::File.new(DEVICE_TREE_D49AP_IM4P)
    expect(file.manifest?).to be false
    expect(file.manifest).to be_nil
  end

  it 'should not have a basename the file' do
    file = MooTool::Img4::File.new(DEVICE_TREE_D49AP_IM4P)
    file_basename = File.basename(DEVICE_TREE_D49AP_IM4P)

    puts "file_basename: #{file.basename}"
    expect(file.basename.length).to be(file_basename.length)
  end
end
