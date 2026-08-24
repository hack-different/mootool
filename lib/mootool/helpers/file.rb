# frozen_string_literal: true

module MooTool
  module Helpers
    # Helpers for handling files and loading them into MooTool models
    module File
      extend ActiveSupport::Concern

      class_methods do
        # Loads data from a file and initializes a new model instance
        #
        # @param path [Models::FileLocation, String, Pathname, Object]
        #   The path to the file or a FileLocation object.
        # @return [Object] A new instance of the class including this module.
        def load(path)
          case path
          when Models::FileLocation
            data = ::File.binread(path.fullname)
            new(data, path.fullname)
          when String, Pathname
            data = ::File.exist?(path) ? ::File.binread(path) : nil
            new(data, path)
          else
            new(data, nil)
          end
        end
      end
    end
  end
end
