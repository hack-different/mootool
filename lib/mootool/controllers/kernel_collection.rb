# frozen_string_literal: true

module MooTool
  module Controllers
    # Controller for extracting or viewing a KernelCollection (.kc file)
    class KernelCollection < ControllerBase
      command 'kc'
      description 'Kernel Collections'

      def extract(command, output_folder)
        file = MachO.open command.file
        input = File.open(command.file, 'rb')

        file.command(:LC_FILESET_ENTRY).each do |entry|
          output_path = File.join(output_folder, entry.entry_id.to_s)
          puts "Writing to #{output_path}"
          output_file = File.open(output_path, 'wb')
          matching = file.command(:LC_SEGMENT_64).find { |c| c.fileoff == entry.fileoff }

          input.seek(matching.fileoff)
          output_file.write input.read(matching.filesize)
          output_file.close
        end
      end
    end
  end
end
