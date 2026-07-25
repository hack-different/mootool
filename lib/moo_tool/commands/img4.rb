# frozen_string_literal: true

module MooTool
  module Commands
    class IMG4 < Thor
      desc 'file', 'The name of the file'
      class_option :file, required: true

      desc 'print', 'Parses and prints pretty versions of an img4/DER'
      option :friendly, type: :boolean, default: true
      def print
        filename = options[:file]
        file = Models::IMG4::File.load(filename)
        file.print(options[:friendly])
      end
    end
  end
end
