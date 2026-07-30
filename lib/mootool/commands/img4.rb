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
      desc :generate_hashes, 'If the contents should be hashed'
      method_option :generate_hashes, type: :boolean, required: false, default: true
      desc :index, 'Index for any relevant files on a live system'
      def index
        indexer = Models::FileIndex.new
        indexer.perform

        indexer.generate_hashes if options[:generate_hashes]

        File.write options[:save_file], JSON.pretty_generate(indexer.index) if options[:save_file]

        ap indexer.index
      end

      desc :index, 'Index for any relevant files on a live system'
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

        results = results.map do |key, value|
          info = Models::IMG4.mappings[key] || {}
          info[:examples] = value
          [key, info]
        end.to_h


        ap({ unique_payload_types: results })
      end

      method_option :path, type: :string, default: nil
      desc 'manifest', 'Prints the manifest of an img4/DER'
      def manifest
        ap Models::IOReg.create(options[:path]).manifests
      end
    end
  end
end
