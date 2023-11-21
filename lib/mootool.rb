# typed: strict
# frozen_string_literal: true

require_relative 'mootool/version'

require 'sorbet-runtime'
require 'macho'
require 'zip'

require_relative 'mootool/core_extensions'

# MooTool
module MooTool
  class Error < StandardError; end

  # Namespace for all command line controllers
  module Controllers; end

  # Your code goes here...
  autoload :Command, 'mootool/command'
  autoload :ControllerBase, 'mootool/controller_base'

  autoload :Img4, 'mootool/models/img4'
  autoload :DeviceTree, 'mootool/models/device_tree'
  autoload :IPSW, 'mootool/models/ipsw'
end
