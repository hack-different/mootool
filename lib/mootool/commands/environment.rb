# frozen_string_literal: true

module MooTool
  module Commands
    # Commands that help understand the exeuction environment
    class Environment < Thor
      desc 'print', 'Print information about the execution environment'
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
