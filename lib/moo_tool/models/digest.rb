# frozen_string_literal: true

module MooTool
  module Models
    class Digest
      attr_reader :value
      attr_accessor :hint

      def initialize(value, hint = nil)
        @hint = hint

        case value
        when String
          @value = value
          @hint = 'SHA1' if value.length == 20
          @hint = 'SHA256' if value.length == 32
          @hint = 'SHA384' if value.length == 48
        when Integer
          @value = [value.to_s(16)].pack('H*')
          @hint = hint
          @integer = true
        else
          raise ArgumentError, "Invalid Input: #{value.inspect}"
        end
      rescue StandardError
        raise "Value #{value} with class #{value.class} could not be parsed"
      end

      def integer?
        @integer
      end

      def files
        @files ||= FileIndex.current.files_with_hash(shasum)
      end

      def self.parse(value)
        new [value].pack('H*')
      end

      def self.digest(value)
        hash = ::Digest::SHA384.digest value
        new hash, 'SHA384'
      end

      def self.create(input, hint = nil)
        if input.is_a?(String) && input.length == 16 && hint.nil?
          UUIDTools::UUID.parse_raw input
        elsif input.is_a?(Array)
          input.map { |i| create(i, hint) }
        elsif input.nil?
          nil
        elsif input.is_a?(Digest)
          input
        else
          Digest.new input, hint
        end
      end

      def to_s
        value
      end

      def shasum
        self.hex
      end

      def hex
        to_s.unpack1('H*').upcase
      end

      def properties
        Digest.manifests.properties_with_hash(shasum)
      end

      def self.manifests
        @manifests ||= IOReg.create
      end

      def self.load_manifests(path)
        @manifest = IOReg.create path
      end

      def as_json(*_options)
        shasum
      end

      def size
        value.size
      end

      def ==(other)
        if other.is_a?(Models::Digest)
          value == other.value
        elsif other.is_a?(String)
          hex == other.unpack1('H*').upcase || hex == other
        else
          value == other
        end
      end

      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      def inspect
        to_s.unpack1('H*').upcase
      end

      module DigestFormatter
        def self.included(base)
          base.send :alias_method, :cast_without_digest, :cast
          base.send :alias_method, :cast, :cast_with_digest
        end

        def cast_with_digest(object, type)
          cast = cast_without_digest(object, type)

          case object
          when MooTool::Helpers::FirmwareEntry
            cast = :firmware_entry
          when Digest
            cast = :digest
          when Pathname
            cast = :path
          when UUIDTools::UUID
            cast = :uuid
          when Models::Certificate
            cast = :certificate
          when OpenSSL::PKey::EC::Point
            cast = :point
          when Certificate::ECCPublicKey
            cast = :ecc_public_key
          when Certificate::ECCSignature
            cast = :ecc_signature
          when Certificate::ECIESEncryption
            cast = :ecc_encryption
          when :ALLOW_ANY_VALUE
            cast = :any_value
          end
          cast
        end

        def awesome_firmware_entry(entry, _options = {})
          values = entry.value
          digest = values[:DGST]
          values.delete(:DGST)
          booleans = values.select { |_k, v| [true, false].include?(v) }.map do |key, value|
            color = value ? :trueclass : :falseclass
            colorize(key, color).to_s
          end
          other = values.reject { |_k, v| [true, false].include?(v) }

          results = ["#{colorize('Firmware', :class)} #{booleans.join(' ')} #{colorize(digest.shasum, :digest)}"]
          results += digest.files.map do |file|
            "#{' ' * @inspector.current_indentation}                          #{colorize('match',
                                                                                         :args)}: #{colorize(
                                                                                           file.fullname, :path
                                                                                         )}"
          end

          if other.any?
            results += other.map do |key, value|
              "#{' ' * @inspector.current_indentation}      #{colorize(key,
                                                                       :symbol)}  #{colorize(value.hint,
                                                                                             :class).rjust(24)} #{colorize(
                                                                                               value.shasum, :digest
                                                                                             )}"
            end
          end

          results.join("\n")
        end

        def awesome_any_value(_input)
          colorize('*** SPLAT ***', :trueclass)
        end

        def awesome_ecc_signature(signature)
          values = signature.to_h
          "#{colorize('ECCSignature', :class)} r=#{colorize(values[:r], :integer)}, s=#{colorize(values[:s], :integer)}"
        end

        def awesome_ecc_encryption(encryption)
          values = encryption.to_h
          "#{colorize('ECIESEncryption',
                      :class)} #{colorize(encryption.group,
                                          :args)} (x=#{colorize(values[:e_x],
                                                                :integer)}, y=#{colorize(values[:e_y],
                                                                                         :integer)}), n=#{colorize(
                                                                                           values[:n], :integer
                                                                                         )}"
        end

        def awesome_ecc_public_key(public_key)
          point_data = public_key.point.to_octet_string(:uncompressed)
          x = point_data[0..(point_data.length / 2)].unpack1('H*').upcase
          y = point_data[(point_data.length / 2)..].unpack1('H*').upcase
          "#{colorize('ECCPublicKey',
                      :class)} #{colorize(public_key.curve.curve_name,
                                          :args)} #{colorize('x=',
                                                             :args)}#{colorize(x,
                                                                               :integer)}, #{colorize('y=',
                                                                                                      :args)}#{colorize(
                                                                                                        y, :integer
                                                                                                      )}"
        end

        def awesome_point(point)
          point_data = point.to_octet_string(:uncompressed)[1..-1]
          x = point_data[0..(point_data.length / 2)].unpack1('H*').upcase
          y = point_data[(point_data.length / 2)..].unpack1('H*').upcase
          "#{colorize('ECCPoint',
                      :class)} #{colorize(point.group.curve_name,
                                          :args)} #{colorize('x=',
                                                             :args)}#{colorize(x,
                                                                               :integer)}, #{colorize('y=',
                                                                                                      :args)}#{colorize(
                                                                                                        y, :integer
                                                                                                      )}"
        end

        def awesome_certificate(object)
          awesome_hash(object.to_h)
        end

        def awesome_digest(object)
          files = object.files.map do |f|
            "#{' ' * @inspector.current_indentation}#{colorize('match', :args)}: #{colorize(f.fullname, :path)}"
          end
          formatted = if object.integer?
                        colorize(object.inspect, :integer)
                      elsif object.hint
                        properties = object.properties.any? ? " (#{object.properties.join(',')})" : ''
                        "#{colorize(object.hint, :class)}#{properties} #{colorize(object.inspect, :digest)}"
                      else
                        colorize(object.inspect, :digest).to_s
                      end

          if files.any?
            "#{formatted}\n#{files.join("\n")}"
          else
            formatted
          end
        end

        def awesome_path(object)
          colorize(object.to_s, :path)
        end

        def awesome_uuid(object)
          colorize(object.to_s, :uuid)
        end
      end
    end
  end
end
