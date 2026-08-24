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
        @certificates = [@certificates] unless @certificates.is_a?(Array)

        friendly = options[:friendly]
        mappings = Models::IMG4.mappings
        if friendly
          @certificates.map do |certificate|
            certificate.to_h.deep_transform_keys do |key|
              new_key = mappings[key]
              new_key.respond_to?(:to_sym) ? new_key.to_sym : new_key
            end
          end
        end

        @certificates.each do |certificate|
          ap certificate
        end
      end

      method_option :export_path, type: :string, default: nil
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

        if options[:export_path]
          Models::CertificateIndex.current.index.each do |id, cert|
            output = File.join(options[:export_path], "#{id.shasum}.der")
            File.open(output, "wb") { |f| f.print cert.openssl_certificate.to_der }
          end
        end

        ap(Models::CertificateIndex.current.index)
      end

      method_option :missing, type: :boolean, default: false
      desc 'roots', 'Indexes certificates throughout the land'
      def roots
        Models::CertificateIndex.load_default_certs
        result = if options[:missing]
                   Models::CertificateIndex.current.index.values.select(&:missing_root?)
                 else
                   Models::CertificateIndex.current.index.values.select(&:self_signed?)
                 end

        ap(result.uniq { |c| c.digest.hex }.map do |c|
          {
            subject: c.subject.to_s,
            issuer: c.issuer.to_s,
            fingerprint: c.fingerprint,
            digest: c.digest
          }
        end)
      end
    end
  end
end
