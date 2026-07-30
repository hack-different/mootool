# frozen_string_literal: true

module MooTool
  module Models
    class CertificateIndex
      attr_accessor :index

      def initialize(_path = nil)
        @index = {}
      end

      def add_certificate(certificate)
        @index[certificate.hash] = certificate
      end

      def self.current
        unless @certificate_index
          @certificate_index = new
          MooTool::Models::FileIndex.current.index.each do |file|
            MooTool::Models.file_guesser(file.fullname)
          end
        end
        @certificate_index
      end

      def matching_key(key)
        key = MooTool::Models::Certificate.formatted_public_key(key)
        index.select do |_hash, certificate|
          key == certificate.formatted_public_key
        end.map do |_hash, certificate|
          { subject: certificate.subject.to_s, fingerprint: certificate.fingerprint,
            generate_hashes: certificate.generate_hashes }
        end.uniq do |entry|
          entry[:generate_hashes].value
        end
      end

      def with_identifier(id)
        index.select do |_hash, certificate|
          certificate.identifiers.include? id
        end
      end

      def self.add_certificate(certificate)
        current.index[certificate.generate_hashes] = certificate
      end

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
            generate_hashes: hash.shasum,
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
