# frozen_string_literal: true

require 'openssl'
require_relative 'decompressor'

module MooTool
  # Module for Apple's IMG4 encryption and signing format
  module Img4
    # An instance of a IMG4 file
    class File
      attr_reader :payload, :manifest

      def initialize(path)
        @path = path
        der = ::File.binread(path)
        @data = OpenSSL::ASN1.decode(der)

        case @data.first.value
        when 'IM4P'
          @type = @data.value[1].value
          @build = @data.value[2].value
          @payload = MooTool::Decompressor.new(@data.value[3].value).value
        when 'IMG4', 'IM4M'
          raise 'Not implemented'
        else
          raise "Unknown IMG4 type #{@data.first.value}"
        end

        @manifest = Manifest.new(@payload) if @payload.start_with?('IM4M')
      end

      def payload?
        !@payload.nil?
      end

      def manifest?
        !@manifest.nil?
      end

      def basename
        basename = ::File.basename(@path)
        extension = ::File.extname(basename)
        "#{basename.chomp(extension)}.#{@type}"
      end

      def extract_payload
        output_path = ::File.join(::File.dirname(@path), basename)
        ::File.write(output_path, @payload)
      end
    end
  end
end
