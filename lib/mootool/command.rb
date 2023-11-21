# typed: true
# frozen_string_literal: true

module MooTool
  # Abstract base command for all command types.
  class Command
    attr_reader :file, :controller, :action, :output_format, :remain

    def self.parse(args)
      Command.new args[2], :human, args[0], args[1], args[3..]
    end

    def initialize(file, _output_format, controller, action, remain)
      @file = file
      @controller = controller
      @output_format = :human
      @remain = remain
      @action = action
    end

    def run!
      MooTool::ControllerBase.load_all

      controller = MooTool::ControllerBase.for_controller @controller
      controller.new.send @action, self, @remain
    end
  end
end
