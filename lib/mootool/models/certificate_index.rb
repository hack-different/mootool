# frozen_string_literal: true

module MooTool
  module Models
    # A combined index of certificates for lookup and validation
    #
    # This class maintains a singleton-like registry of certificates, allowing
    # lookup by digest, public key, or other identifiers.
    class CertificateIndex
      # @return [Hash{Models::Digest => Models::Certificate}] The index of certificates.
      attr_accessor :index

      # Initializes a new CertificateIndex
      #
      # @param _path [String, nil] Unused path parameter.
      def initialize(_path = nil)
        @index = {}
      end

      # Loads default certificates from the project's data path
      #
      # @return [void]
      def self.load_default_certs
        Dir[File.join(DATA_PATH, '**/*.{cer,der}')].each do |path|
          Models::Certificate.load path
        end
      end

      # Adds a certificate to the index
      #
      # @param certificate [Models::Certificate, OpenSSL::X509::Certificate] The certificate to add.
      # @return [Models::Certificate] The added certificate.
      def add_certificate(certificate)
        case certificate
        when Models::Certificate
          @index[certificate.digest] = certificate
        when OpenSSL::X509::Certificate
          certificate = Certificate.new certificate
          @index[certificate.digest] = certificate
        end
      end

      # Returns the singleton-like current certificate index
      #
      # @return [CertificateIndex]
      def self.current
        unless @certificate_index
          @certificate_index = new
          MooTool::Models::FileIndex.current.index.each do |file|
            MooTool::Models.file_guesser(file.fullname)
          end
        end
        @certificate_index
      end

      # Finds certificates with a matching public key
      #
      # @param key [OpenSSL::PKey::PKey, Models::ECCPublicKey, Models::RSAPublicKey] The key to match.
      # @return [Array<Hash>] List of matching certificate summaries.
      def matching_key(key)
        key = MooTool::Models::Certificate.formatted_public_key(key)
        results = index.select do |_hash, certificate|
          key == certificate.formatted_public_key
        end
        results = results.map do |_hash, certificate|
          { subject: certificate.subject.to_s, fingerprint: certificate.fingerprint,
            hash: certificate.digest }
        end
        results.uniq { |entry| entry[:hash].value }
      end

      # Finds certificates containing a specific identifier
      #
      # @param id [String] The identifier to search for (e.g., fingerprint or key ID).
      # @return [Hash{Models::Digest => Models::Certificate}] Matching certificates.
      def with_identifier(id)
        index.select do |_hash, certificate|
          certificate.identifiers.include? id
        end
      end

      # Adds a certificate to the current singleton index
      #
      # @param certificate [Models::Certificate] The certificate to add.
      # @return [void]
      def self.add_certificate(certificate)
        current.index[certificate.digest] = certificate
      end

      # Saves the index to a JSON file
      #
      # @param path [String, Pathname] Path to save the JSON file.
      # @return [void]
      def save(path)
        data = index.map do |hash, certificate|
          pkey = certificate.formatted_public_key
          pkey = case pkey
                 when Models::Digest
                   pkey.shasum
                 when Models::ECCPublicKey
                   point_data = pkey.point.to_octet_string(:uncompressed)
                   cartisian_data = point_data[1..]
                   x_data = cartisian_data[0..(cartisian_data.size / 2)]
                   y_data = cartisian_data[(cartisian_data.size / 2)..]
                   {
                     curve: pkey.curve.curve_name,
                     point: Models::Digest.create(point_data).hex,
                     x: Models::Digest.create(x_data).hex,
                     y: Models::Digest.create(y_data).hex
                   }
                 else
                   pkey.to_h
                 end

          {
            hash: hash.shasum,
            pkey: pkey,
            **certificate.to_h
          }
        end

        json = JSON.pretty_generate(data)
        File.write(path, json)
      end
    end
  end
end
