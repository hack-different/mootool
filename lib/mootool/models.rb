# frozen_string_literal: true

module MooTool
  # Data models used by MooTool
  module Models
    # Attempts to identify and load a file using various known models
    #
    # @param file [String, Pathname, Models::FileLocation] The file to identify.
    # @return [Array<Class>] The list of models attempted (Note: currently returns the array of models).
    def self.file_guesser(file)
      [Models::IMG4::File, Models::Certificate, Models::RemoteRequest, Models::RemoteResponse].each do |model|
        model.load(file)
      rescue Exception
        nil
      end
    end
  end
end
