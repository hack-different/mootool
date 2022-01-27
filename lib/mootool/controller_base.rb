# frozen_string_literal: true

CONTROLLERS_PATH = File.join(File.dirname(__FILE__), 'controllers')

module MooTool
  class ControllerBase
    def self.load_all
      Dir.glob(File.join(CONTROLLERS_PATH, '*')).each do |file|
        require file
      end
    end

    def self.for_controller(name)
      @@controllers.find { |c| c.command == name }
    end

    def self.inherited(child)
      @@controllers ||= []
      @@controllers << child
    end

    class << self
      def command(command = nil)
        @command = command if command
        @command
      end

      def description(description)
        @description = description
      end
    end
  end
end
