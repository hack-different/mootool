# typed: true
# frozen_string_literal: true

module MooTool
  module Commands
    # Controller for extracting or viewing a KernelCollection (.kc file)
    class KernelCollection < Thor
      desc 'extract', 'Extracts a KernelCollection (.kc file)'
      def extract(command, output_folder)
        file = command.file
        File.open(command.file, 'rb') do |input|
          file.command(:LC_FILESET_ENTRY).each do |entry|
            output_path = File.join(output_folder, entry.entry_id.to_s)
            puts "Writing to #{output_path}"
            File.open(output_path, 'wb') do |output_file|
              # rubocop:disable Naming/VariableNumber
              # We do not have control of this name as it is part of ruby-macho
              matching = file.command(:LC_SEGMENT_64).find { |c| c.fileoff == entry.fileoff }
              # rubocop:enable Naming/VariableNumber

              input.seek(matching.fileoff)
              output_file.write input.read(matching.filesize)
              output_file.close
            end
          end
        end
      end
    end
  end
end
