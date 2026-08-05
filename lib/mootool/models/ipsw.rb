# typed: true
# frozen_string_literal: true

module MooTool
  module Models
    # Model of an IPSW file
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
end
