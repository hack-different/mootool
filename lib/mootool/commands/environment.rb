# frozen_string_literal: true

module MooTool
  module Commands
    # CLI commands for inspecting the current Ruby execution environment.
    class Environment < Thor
      desc 'print', 'Print information about the execution environment'
      # Prints information about the Ruby execution environment.
      #
      # Includes the current load paths and loaded features.
      #
      # @return [void]
      # @example Display environment details
      #   mootool env print
      def print
        result = {
          load_paths: $LOAD_PATH,
          loaded_features: $LOADED_FEATURES
        }

        ap(result)
      end
    end
  end
end
