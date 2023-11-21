# typed: true
# frozen_string_literal: true

require 'zip'
require 'plist'
require 'net/http'

module MooTool
  # Represents a single IPSW package
  class IPSW
    attr_reader :manifest

    def initialize(file)
      @file = file
      @zip = Zip::File.open(file)
      manifest = @zip.find_entry('BuildManifest.plist')

      raise 'Invalid IPSW, does not contain BuildManifest.plist' unless manifest

      @manifest = Plist.parse_xml manifest.get_input_stream.read
    end
  end
end
