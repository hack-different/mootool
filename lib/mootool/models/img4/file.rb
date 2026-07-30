# frozen_string_literal: true

# An instance of a IMG4 file
module MooTool
  module Models
    module IMG4
      class File
        attr_reader :payload, :manifest, :file_index

        include MooTool::Helpers::IMG4

        DER_PAYLOADS = %w[trst].freeze

        def self.load(path)
          case path
          when FileLocation
            data = ::File.binread(path.fullname)
            new(data, path.fullname)
          when String, Pathname
            data = ::File.binread(path)
            new(data, path)
          end
        end

        def self.parse_signature(signature)
          signature = signature.value if signature.is_a?(OpenSSL::ASN1::OctetString)
          if signature.size > 128
            Models::Digest.create(signature, 'RSASignature')
          else
            ::MooTool::Models::ECCSignature.create(signature)
          end
        end

        def self.parse_certificates(certificates)
          certificates.map do |certificate|
            certificate_data = certificate.value if certificate.is_a?(Models::Digest)
            certificate_data = certificate.to_der if certificate.respond_to?(:to_der)
            Models::Certificate.new OpenSSL::X509::Certificate.new(certificate_data)
          end
        end

        def payload_type
          @content[:IM4P]&.type&.to_sym
        end

        def manifest_type
          @content[:IM4M]&.type&.to_sym
        end

        def to_h
          content = @content.transform_values(&:inspect)

          content[:file_type] = @type
          content[:hashes] = hashes
          content
        end

        def initialize(der, filename = nil)
          MooTool::Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
          @filename = filename

          raw_data = der.is_a?(MooTool::Models::Digest) ? der.value : der

          @hashes = [MooTool::Models::Digest.create(::Digest::SHA384.digest(raw_data))]
          @data = OpenSSL::ASN1.decode(raw_data)
          @type = @data.value[0].value
          @content = {}

          case @type
          when 'IM4P'
            @content[:IM4P] = MooTool::Models::IMG4::IMG4Payload.new(@data)
          when 'IM4M'
            @content[:IM4M] = MooTool::Models::IMG4::IMG4Manifest.new(@data)
          when 'IMG4'
            @content[:IM4P] = MooTool::Models::IMG4::IMG4Payload.new(@data.value[1])
            @content[:IM4M] = MooTool::Models::IMG4::IMG4Manifest.new(@data.value[2])
          when 'secb'
            @value = construct(@data)
            @content[:secb] = @value.drop(1).map do |entry|
              case entry[0]
              when 'trst', 'rssl'
                { entry[0].to_sym => File.parse_certificates(entry.drop(1)) }
              when 'rvok'
                { entry[0].to_sym => entry[1] }
              when 'trpk'
                { entry[0].to_sym => entry.drop(1).map { |e| MooTool::Models::ECCPublicKey.new e } }
              end
            end.reduce(&:merge)
          when 'comb'
            @value = construct(@data)
            @content[:comb] = @value.drop(1).map do |entry|
              { entry[0] => File.new(entry[1]) }
            end.reduce(&:merge)
          else
            @content = @value.map(&:to_h).reduce(&:merge)
          end

          # @content[:validity] = validate_signature
        end

        def validted_certificate_chain
          @content[:IM4M].certificates.last
        end

        def validate_signature
          leaf_certificate = validted_certificate_chain
          [OpenSSL::Digest.new('SHA384'), OpenSSL::Digest.new('SHA256')].flat_map do |digest|
            values = %i[IM4M IM4P].map do |kind|
              @content[kind]&.to_bytes
            end.compact

            hashes = values.map do |value|
              OpenSSL::Digest::SHA384.digest(value)
            end.compact

            signatures = %i[IM4P IM4M].map do |kind|
              signature = @content[kind]&.signature
              signature.respond_to?(:value) ? signature.value : signature
            end.compact

            signatures.flat_map do |signature|
              value_result = values.map do |value|
                { digest.hexdigest(value) => leaf_certificate.public_key.verify(digest, signature, value) }
              end

              hashes_result = hashes.map do |hash|
                { digest.hexdigest(hash) => leaf_certificate.public_key.verify(digest, signature, hash) }
              end

              hash_hashes_result = hashes.map do |hash|
                { digest.hexdigest(hash) => leaf_certificate.public_key.verify(digest, signature, digest.digest(hash)) }
              end

              join_result = [
                { digest.hexdigest(hashes.join) => leaf_certificate.public_key.verify(digest, signature, hashes.join) }
              ]

              value_result + hashes_result + hash_hashes_result + join_result
            end
          end.reduce(&:merge)
        end

        def to_h
          result = @content.dup
          result[:hashes] = hashes
          result.deep_symbolize_keys
        end

        def parse_element(element)
          { element.value[0].value.to_sym => element.value[1].value }
        end

        def parse_pair(input)
          input.value.to_a.each_slice(2).to_h do |key, value|
            [key.value, value]
          end
        end

        def types
          result = [payload_type]
          if @content[:comb]
            result += @content[:comb].keys
          end
          if @content[:secb]
            result += @content[:secb].keys
          end
          result.compact.map { |r| r.to_sym }
        end

        def payload
          @content[:IM4P].payload
        end

        def payload?
          !@content[:IM4P].nil?
        end

        def manifest?
          !@content[:IM4M].nil?
        end

        def basename
          basename = ::File.basename(@filename)
          extension = ::File.extname(basename)
          "#{basename.chomp(extension)}.#{@type}"
        end

        def extract_payload
          output_path = ::File.join(::File.dirname(@filename), basename)
          ::File.write(output_path, @payload)
        end

        def hashes
          result = @hashes.dup

          result += @content[:comb].flat_map { |_k, v| v.hashes } if @content[:comb]

          result += @content[:IM4M].hashes if @content[:IM4M]

          result += @content[:IM4P].hashes if @content[:IM4P]

          result.map { |h| h.respond_to?(:value) ? h.value : h }.uniq.map { |h| Models::Digest.create(h) }
        end

        def print(friendly)
          output = to_h
          if friendly
            mappings = IMG4.mappings

            output.deep_transform_keys! do |key|
              new_key = mappings.dig(key.to_s, 'title') || mappings.dig(key.to_s, 'description') || key
              new_key.respond_to?(:to_sym) ? new_key.to_sym : new_key
            end
          end

          ap(output)
        end
      end
    end
  end
end
