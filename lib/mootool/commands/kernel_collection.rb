# typed: true
# frozen_string_literal: true

module MooTool
  module Commands
    # CLI commands for extracting or viewing Apple Kernel Collection (.kc) files.
    class KernelCollection < Thor
      desc 'extract', 'Extracts a KernelCollection (.kc file)'
      # Extracts the components of a Kernel Collection file to the specified output folder.
      #
      # @param command [Object] an object representing the kernel collection command context, expected to have a `file` attribute.
      # @param output_folder [String] the directory where the extracted components should be saved.
      # @return [void]
      # @example Extract components from a kernel collection
      #   mootool kc extract kernelcache.release.iphone14 ./extracted_kernels
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
