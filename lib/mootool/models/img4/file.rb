# frozen_string_literal: true

# An instance of a IMG4 file
module MooTool
  module Models
    module IMG4
      # An IMG4 file, or, occasionally, a file read in from another source
      class File
        attr_reader :manifest, :file_index

        include MooTool::Helpers::IMG4
        include Helpers::Signature
        include Helpers::File

        def payload_type
          @content[:IM4P]&.type&.to_sym
        end

        def manifest_type
          @content[:IM4M]&.type&.to_sym
        end

        def initialize(der, filename = nil)
          MooTool::Models::FileIndex.load '/Users/rickmark/Desktop/index.json'
          @filename = filename

          raw_data = der.is_a?(MooTool::Models::Digest) ? der.value : der

          @hashes = [MooTool::Models::Digest.create(::Digest::SHA384.digest(raw_data))]
          @data = OpenSSL::ASN1.decode(raw_data)
          @type = @data.value[0].value
          @content = {}
          parse
        end

        def validted_certificate_chain
          @content[:IM4M].certificates.last
        end

        def to_h
          result = @content.dup
          result[:hashes] = hashes
          result.deep_symbolize_keys
        end

        def types
          result = [payload_type]
          result += @content[:comb].keys if @content[:comb]
          result += @content[:secb].keys if @content[:secb]
          result.compact.map(&:to_sym)
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

        def print
          ap(to_h.deep_transform_keys { |k| Models::IMG4.key_name(k) })
        end

        private

        def parse_secb
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
        end

        def parse_comb
          @value = construct(@data)
          @content[:comb] = @value.drop(1).map do |entry|
            { entry[0] => File.new(entry[1]) }
          end.reduce(&:merge)
        end

        def parse
          case @type
          when 'IM4P'
            @content[:IM4P] = MooTool::Models::IMG4::IMG4Payload.new(@data)
          when 'IM4M'
            @content[:IM4M] = MooTool::Models::IMG4::IMG4Manifest.new(@data)
          when 'IMG4'
            @content[:IM4P] = MooTool::Models::IMG4::IMG4Payload.new(@data.value[1])
            @content[:IM4M] = MooTool::Models::IMG4::IMG4Manifest.new(@data.value[2])
          when 'secb'
            parse_secb
          when 'comb'
            parse_comb
          else
            @content = @value.map(&:to_h).reduce(&:merge)
          end
        end
      end
    end
  end
end
