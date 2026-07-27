module MooTool
  module Commands
    class Certificate < Thor
      desc 'print','Prints the certificate'
      def print(file)
        pem_data = File.read(file)
        certificates = pem_data.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |text|
          ::MooTool::Models::Certificate.new OpenSSL::X509::Certificate.new(text)
        end

        certificates.each do |certificate|
          ap certificate
        end
      end
    end
  end
end