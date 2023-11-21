# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'net/https'

IPSW_URL = URI('https://updates.cdn-apple.com/2022SpringFCS/fullrestores/002-82670/A85D86CB-3DB5-4159-8F58-EA9D589F4849/iBridge2,1,iBridge2,10,iBridge2,12,iBridge2,14,iBridge2,15,iBridge2,16,iBridge2,19,iBridge2,20,iBridge2,21,iBridge2,22,iBridge2,3,iBridge2,4,iBridge2,5,iBridge2,6,iBridge2,7,iBridge2,8_6.4_19P4243_Restore.ipsw')
IPSW_FILE = File.join(File.dirname(__FILE__), '..', 'fixtures', 'InputFixture.ipsw')

describe MooTool::IPSW do
  before :all do
    File.binwrite(IPSW_FILE, Net::HTTP.get(IPSW_URL)) unless File.exist?(IPSW_FILE)
  end

  it 'should load a IPSW file' do
    open_thing = MooTool::IPSW.new IPSW_FILE
    expect(open_thing).to_not be_nil
  end

  it 'should load a IPSW file and the manifest should be valid' do
    open_thing = MooTool::IPSW.new IPSW_FILE
    expect(open_thing.manifest).to_not be_nil
  end
end
