# frozen_string_literal: true

require 'mootool/version'

require 'bundler/setup'

require 'macho'

module MooTool
  class Error < StandardError; end
  # Your code goes here...
  autoload :Command, 'mootool/command'
  autoload :ControllerBase, 'mootool/controller_base'
end
