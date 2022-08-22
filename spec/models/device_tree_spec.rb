# frozen_string_literal: true

require 'spec_helper'

require 'mootool/models/device_tree'

DEVICE_TREE_D49AP = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.d49ap.dtre')
DEVICE_TREE_J274AP = File.join(File.dirname(__FILE__), '..', 'fixtures', 'DeviceTree.j274ap.dtre')

describe MooTool::Models::DeviceTree do
  it 'should be able to parse a device tree' do
    device_tree = MooTool::Models::DeviceTree.open(DEVICE_TREE_D49AP)
    expect(device_tree).to_not be_nil
  end
end
