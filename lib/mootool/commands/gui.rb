# frozen_string_literal: true

require 'gtk3'

module MooTool
  module Commands
    # CLI commands for parsing, handling, and indexing certificates.
    class GUI < Thor
      method_option :file, type: :string, desc: 'File to print'
      desc 'print FILE', 'Display Data in GUI'
      def print
        Models::IMG4.friendly = true
        app = MooTool::GUI::Application.new

        file = options[:file]
        if file
          app.run([$PROGRAM_NAME, file])
        else
          app.run([$PROGRAM_NAME])
        end
      end
    end
  end
end
