# frozen_string_literal: true

module MooTool
  module Commands
    # CLI commands for parsing and interacting with IMG4 and DER files.
    class IMG4 < Thor
      method_option :manifest, type: :string, required: false, default: nil
      method_option :friendly, type: :boolean, default: true
      desc 'print', 'Parses and prints pretty versions of an img4/DER'
      # Parses and prints a representation of an IMG4 or DER file as a tree.
      #
      # @param filename [String] the path to the file to be parsed.
      # @return [void]
      # @example Print an IMG4 file tree
      #   mootool img4 print firmware.img4
      def print(filename)
        Models::Digest.load_manifests(options[:manifest]) if options[:manifest]
        Models::CertificateIndex.load_default_certs
        file = Models::IMG4::File.load(filename)
        Models::IMG4.friendly = options[:friendly]
        puts file.to_tree.render
      end

      desc :save_file, 'The file to save the results too'
      method_option :save_file, type: :string, required: false, default: nil
      desc :generate_hashes, 'If the contents should be hashed'
      method_option :generate_hashes, type: :boolean, required: false, default: true
      desc :index, 'Index for any relevant files on a live system'
      # Indexes relevant IMG4/DER files on the live system.
      #
      # @return [void]
      # @example Index system files and save to a JSON file
      #   mootool img4 index --save-file index.json
      def index
        indexer = Models::FileIndex.new
        indexer.perform

        indexer.generate_hashes if options[:generate_hashes]

        File.write options[:save_file], JSON.pretty_generate(indexer.index) if options[:save_file]

        ap indexer.index
      end

      desc :index, 'Index for any relevant files on a live system'
      # Analyzes system files to find and display unique IMG4 payload types.
      #
      # @return [void]
      # @example List unique payload types and their examples
      #   mootool img4 types
      def types
        indexer = Models::FileIndex.new
        indexer.perform

        results = {}

        indexer.index.select(&:img4?).flat_map do |file|
          loaded = Models::IMG4::File.load(file)
          loaded.types.compact.map do |type|
            results[type] ||= []
            results[type] << file.fullname
          end
        end

        results = results.to_h do |key, value|
          info = Models::IMG4.mappings[key] || {}
          info[:examples] = value
          [key, info]
        end

        ap({ unique_payload_types: results })
      end

      method_option :path, type: :string, default: nil
      desc 'manifest', 'Prints the manifest of an img4/DER'
      # Extracts and prints the manifest of an IMG4/DER from the IORegistry.
      #
      # @return [void]
      # @example Print the manifest for a specific registry path
      #   mootool img4 manifest --path "IOService:/AppleARMPE/chosen"
      def manifest
        ap Models::IOReg.create(options[:path]).manifests
      end

      desc 'extract <file> [outdir]', 'Extracts an img4/DER file'
      def extract(file, outdir=nil)
        ap Models::IMG4::File.load(file).extract_payload(outdir)
      end
    end
  end
end
