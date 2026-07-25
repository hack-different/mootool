# frozen_string_literal: true

require 'thor'

module MooTool
  class Command < Thor
    package_name 'moo_tool'

    desc 'img4', 'Commands for img4, apticket, lpol'
    subcommand :img4, MooTool::Commands::IMG4
  end
end
