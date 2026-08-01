# frozen_string_literal: true

require 'thor'

module MooTool
  # Base top level command, subcommands are referenced from here
  class Command < Thor
    package_name 'mootool'

    desc 'img4', 'Commands for img4, apticket, lpol'
    subcommand :img4, MooTool::Commands::IMG4

    desc 'cert', 'Certificate parsing and handling'
    subcommand :cert, MooTool::Commands::Certificate

    desc 'activation', 'MobileActivation parsing and handling'
    subcommand :activation, MooTool::Commands::Activation

    desc 'kc', 'Kernel Collections'
    subcommand :kc, MooTool::Commands::KernelCollection

    desc 'env', 'Environment Variables'
    subcommand :env, Commands::Environment
  end
end
