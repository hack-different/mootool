# frozen_string_literal: true

module MooTool
  module Models
    class Digest
      attr_reader :value, :files
      attr_accessor :hint

      def initialize(value, hint = nil)
        @hint = hint
        @files = []

        case value
        when String
          @value = value
          @hint = 'SHA1' if value.length == 20
          @hint = 'SHA256' if value.length == 32
          @hint = 'SHA384' if value.length == 48
        when Integer
          @value = [value.to_s(16)].pack('H*')

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

      def self.parse(value)
        new [value].pack('H*')
      end

      def self.create(input, hint = nil)
        if input.is_a?(String) && input.length == 16
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
          shasum == other.unpack1('H*').upcase
        else
          value == other
        end
      end

      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      def file_names(file_index)
        if file_index.has_hash? shasum
          @files = file_index.files_with_hash(shasum).map { |f| f.to_ref(shasum) }.uniq

          { hash: self, files: @files }
        else
          self
        end
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
          when Certificate::ECCSignature
            cast = :ecc_signature
          when Certificate::ECIESEncryption
            cast = :ecc_encryption
          when :ALLOW_ANY_VALUE
            cast = :any_value
          end
          cast
        end

        def awesome_firmware_entry(entry, options={})
          values = entry.value
          digest = values[:DGST]
          values.delete(:DGST)
          booleans = values.select{ |k,v| [true, false].include?(v)}.map do |key, value|
            color = value ? :trueclass : :falseclass
            "#{colorize(key, color)}"
          end
          other = values.select { |k,v| not [true, false].include?(v) }

          if other.any?
            results = [ "#{colorize('Firmware', :class)} #{booleans.join(' ')} #{colorize(digest.shasum, :digest)}" ]
            results += digest.files.map do |file|
              "#{" " * @inspector.current_indentation}              #{colorize('file match', :args)}: #{colorize(file, :path)}"
            end
            results += other.map do |key, value|
               "#{" " * @inspector.current_indentation}      #{colorize(key, :symbol)}  #{colorize(value.hint, :class).rjust(24)} #{colorize(value.shasum, :digest)}"
            end

            results.join("\n")
          else
            "#{colorize('Firmware', :class)} #{booleans.join(' ')} #{colorize(digest.shasum, :digest)}"
          end

        end

        def awesome_any_value(input)
          colorize('*** SPLAT ***', :trueclass)
        end



        def awesome_ecc_signature(signature)
          values = signature.to_h
          "#{colorize('ECCSignature', :class)} r=#{colorize(values[:r], :integer)}, s=#{colorize(values[:s], :integer)}"
        end

        def awesome_ecc_encryption(encryption)
          values = encryption.to_h
          "#{colorize('ECIESEncryption', :class)} #{colorize(encryption.group, :args)} (x=#{colorize(values[:e_x], :integer)}, y=#{colorize(values[:e_y], :integer)}), n=#{colorize(values[:n], :integer)}"
        end

        def awesome_point(point)
          point_data = point.to_octet_string(:uncompressed)
          x = point_data[0..(point_data.length / 2)].unpack1('H*').upcase
          y = point_data[(point_data.length / 2)..].unpack1('H*').upcase
          "#{colorize('ECCPoint',
                      :class)} #{colorize(point.group.curve_name,
                                          :symbol)} #{colorize('x=',
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
          if object.integer?
            colorize(object.inspect, :integer)
          elsif object.hint
            properties = object.properties.any? ? " (#{object.properties.join(',')})" : ""
            "#{colorize(object.hint, :class)}#{properties} #{colorize(object.inspect, :digest)}"
          else
            colorize(object.inspect, :digest)
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
