# frozen_string_literal: true

require 'gtk3'

module MooTool
  module Commands
    # CLI commands for parsing, handling, and indexing certificates.
    class GUI < Thor
      desc 'print FILE', 'Display Data in GUI'
      def print(file)
        app = MooTool::GUI::Application.new

        app.run([$0, file])
      end
    end
  end
end
