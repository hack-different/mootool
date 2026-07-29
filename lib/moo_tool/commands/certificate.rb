# frozen_string_literal: true

module MooTool
  module Commands
    class Certificate < Thor
      desc 'friendly', 'Print in a friendly way'
      option :friendly, type: :boolean, default: true
      desc 'print', 'Prints the certificate'
      def print(file)
        file_data = File.read(file)
        @certificates = if file_data.include?('-----BEGIN CERTIFICATE-----')
                          file_data.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |text|
                            ::MooTool::Models::Certificate.new OpenSSL::X509::Certificate.new(text)
                          end

                        else
                          [::MooTool::Models::Certificate.new(OpenSSL::X509::Certificate.new(file_data))]
                        end

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

        @certificates.each do |certificate|
          ap certificate
        end
      end

      method_option :save_file, type: :string, default: nil
      desc 'index', 'Indexes certificates throughout the land'
      def index
        Models::FileIndex.current.index.each do |file|
          Models.file_guesser(file.fullname)
        end

        if options[:save_file]
          Models::CertificateIndex.current.save options[:save_file]
        end

        ap(Models::CertificateIndex.current.index)
      end
    end
  end
end
