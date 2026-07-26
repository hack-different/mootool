
module MooTool
  module Models
    class Digest
      attr_reader :value

      def initialize(value)
        case value
        when String
          @value = value
        when Integer
          @value = [value.to_s(16)].pack('H*')
          @integer = true
        else
          raise ArgumentError, "Invalid Input: #{value.inspect}"
        end
      rescue => e
        raise "Value #{value} with class #{value.class} could not be parsed"
      end

      def integer?
        @integer
      end

      def self.parse(value)
        new [value].pack('H*')
      end

      def self.create(input)
        if input.is_a?(String) && input.length == 16
          UUIDTools::UUID.parse_raw input
        elsif input.is_a?(Array)
          input.map { |i| create(i) }
        elsif input.nil?
          nil
        elsif input.is_a?(Digest)
          input
        else
          Digest.new input
        end
      end

      def to_s
        value
      end

      def shasum
        to_s.unpack1('H*').upcase
      end

      def as_json(*options)
        shasum
      end

      def ==(other)
        ap(other) if self.shasum == '617E782EE46D0ECB9D8DB0BEA211F17BB5DDEB33366E5D7ABB0B668C726D7AEE51881330BC136CB738D8361D731479A3'
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
          { hash: self,
            files:
              file_index.files_with_hash(shasum).map {|f| f.to_ref(shasum)} }
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
          when Digest
            cast = :digest
          when Pathname
            cast = :path
          when UUIDTools::UUID
            cast = :uuid
          when Models::Certificate
            cast = :certificate
          end
          cast
        end

        def awesome_certificate(object)
          awesome_hash(object.to_h)
        end
        def awesome_digest(object)
          if object.integer?
            colorize(object.inspect, :integer)
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