# frozen_string_literal: true

module MooTool
  module Models
    module IMG4
      class IMG4Manifest
        include MooTool::Helpers::IMG4

        attr_reader :certificates, :signature

        def initialize(input)
          @input = input

          @data = if @input.value.size == 1
                    input.value[0]
                  else
                    input
                  end

          @version = @data.value[1].value.to_i
          @body = construct(@data.value[2])
          @signature = File.parse_signature(@data.value[3]) if @data.value[3]
          @certificates = File.parse_certificates(@data.value[4]) if @data.value[4]
        end

        def to_h
          {
            version: @version,
            body: @body,
            signature: @signature,
            certificates: @certificates
          }
        end

        def inspect
          to_h.ai
        end

        def to_bytes
          @input.to_der
        end

        def hashes
          [
            Models::Digest.create(::Digest::SHA384.digest(to_bytes)),
            Models::Digest.create(::Digest::SHA384.digest(@data.to_der)),
            Models::Digest.create(::Digest::SHA384.digest(@data.value[2].to_der))
          ]
        end
      end
    end
  end
end
