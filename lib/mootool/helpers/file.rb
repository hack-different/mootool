# frozen_string_literal: true

module MooTool
  module Helpers
    # Helpers for handling files
    module File
      extend ActiveSupport::Concern

      class_methods do
        def load(path)
          case path
          when Models::FileLocation
            data = ::File.binread(path.fullname)
            new(data, path.fullname)
          when String, Pathname
            data = ::File.binread(path)
            new(data, path)
          else
            new(data, nil)
          end
        end
      end
    end
  end
end
