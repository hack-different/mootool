# typed: false
# frozen_string_literal: true

require 'rspec/core'

RSpec.describe MooTool do
  it 'has a version number' do
    expect(MooTool::VERSION).not_to be nil
  end
end
