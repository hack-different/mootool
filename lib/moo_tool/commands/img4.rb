# frozen_string_literal: true

module MooTool
  module Commands
    class IMG4 < Thor
      method_option :manifest, type: :string, required: false, default: nil
      method_option :friendly, type: :boolean, default: true
      desc 'print', 'Parses and prints pretty versions of an img4/DER'
      def print(filename)
        Models::Digest.load_manifests(options[:manifest]) if options[:manifest]
        file = Models::IMG4::File.load(filename)
        file.print(options[:friendly])
      end

      desc :save_file, 'The file to save the results too'
      method_option :save_file, type: :string, required: false, default: nil
      desc :hash, 'If the contents should be hashed'
      method_option :hash, type: :boolean, required: false, default: true
      desc :index, 'Index for any relevant files on a live system'
      def index
        indexer = Models::FileIndex.new

        indexer.hash if options[:hash]

        File.write options[:save_file], JSON.pretty_generate(indexer.index) if options[:save_file]

        ap indexer.index
      end

      method_option :path, type: :string, default: nil
      desc 'manifest', 'Prints the manifest of an img4/DER'
      def manifest
        ap Models::IOReg.create(options[:path]).manifests
      end
    end
  end
end
