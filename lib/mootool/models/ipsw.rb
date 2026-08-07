# typed: true
# frozen_string_literal: true

module MooTool
  module Models
    # Represents an Apple iPhone Software (IPSW) package.
    class IPSW
      # @return [Hash] The parsed BuildManifest.plist content.
      attr_reader :manifest

      # Initializes a new IPSW instance.
      #
      # @param file [String] The path to the IPSW file.
      # @raise [RuntimeError] If the IPSW does not contain a BuildManifest.plist.
      def initialize(file)
        @file = file
        @zip = Zip::File.open(file)
        manifest = @zip.find_entry('BuildManifest.plist')

        raise 'Invalid IPSW, does not contain BuildManifest.plist' unless manifest

        @manifest = Plist.parse_xml manifest.get_input_stream.read
      end
    end
  end
end
