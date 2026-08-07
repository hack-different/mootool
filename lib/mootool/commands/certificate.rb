# frozen_string_literal: true

module MooTool
  module Commands
    # CLI commands for parsing, handling, and indexing certificates.
    class Certificate < Thor
      desc 'friendly', 'Print in a friendly way'
      option :friendly, type: :boolean, default: true
      desc 'print', 'Prints the certificate'
      # Parses and prints one or more certificates from a file.
      #
      # Optionally transforms keys to more human-readable names using IMG4 mappings.
      #
      # @param file [String] the path to the certificate file.
      # @return [void]
      # @example Print a certificate
      #   mootool cert print example.crt
      def print(file)
        @certificates = Models::Certificate.load(file)

        friendly = options[:friendly]
        mappings = Models::IMG4.mappings
        if friendly
          @certificates.map do |certificate|
            certificate.to_h.deep_transform_keys do |key|
              new_key = mappings.dig(key.to_s, 'title') || mappings.dig(key.to_s, 'description') || key
              new_key.respond_to?(:to_sym) ? new_key.to_sym : new_key
            end
          end
        end

        @certificates.each do |_certificate|
          ap c
        end
      end

      method_option :save_file, type: :string, default: nil
      desc 'index', 'Indexes certificates throughout the land'
      # Indexes certificates found in the environment and optionally saves the index.
      #
      # @return [void]
      # @example Index certificates and save results
      #   mootool cert index --save-file index.json
      def index
        Models::CertificateIndex.load_default_certs
        Models::FileIndex.current.index.each do |file|
          Models.file_guesser(file.fullname)
        end

        Models::CertificateIndex.current.save options[:save_file] if options[:save_file]

        ap(Models::CertificateIndex.current.index)
      end
    end
  end
end
