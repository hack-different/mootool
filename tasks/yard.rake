# frozen_string_literal: true

require 'yard'

desc 'Build All Static Content / Documentation'
YARD::Rake::YardocTask.new :docs do |yard|
  yard.files = %w[lib/**/*.rb - README.md LICENSE.md]

  yard.options = [
    '--output-dir', 'doc/api',
    '--title', "MooTool macOS' Other Tooling",
    '--private',
    '--protected'
  ]
end
