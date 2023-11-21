# typed: false
# frozen_string_literal: true

require 'spec_helper'

require 'mootool/models/device_tree'
require 'mootool/models/img4'
require 'yaml'

DEVICE_TREE_D49AP = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.d49ap.dtre')
DEVICE_TREE_IM4P_D49AP = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.d49ap.im4p')
DEVICE_TREE_J274AP = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.j274ap.dtre')

TMP_DIR = File.join(File.dirname(__FILE__), '..', '..', 'tmp')
YAML_OUT_FILE = File.join(TMP_DIR, 'output_data.yaml')

FileUtils.mkdir_p TMP_DIR

describe MooTool::DeviceTree do
  it 'should be able to parse a device tree' do
    device_tree = MooTool::DeviceTree.open(DEVICE_TREE_D49AP)
    expect(device_tree).to_not be_nil
    puts device_tree.to_h
  end

  it 'should parse a device tree from a IMG4 file' do
    image = MooTool::Img4::File.new(DEVICE_TREE_IM4P_D49AP)
    device_tree = MooTool::DeviceTree.new(image.payload)
    expect(device_tree).to_not be_nil
  end

  it 'should be writable to a YAML file' do
    device_tree = MooTool::DeviceTree.open(DEVICE_TREE_D49AP)
    expect(device_tree).to_not be_nil
    hash_value = device_tree.to_h
    File.write(YAML_OUT_FILE, YAML.dump(hash_value))
  end
end
