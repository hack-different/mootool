# frozen_string_literal: true

module MooTool
  module Commands
    class Activation < Thor
      desc 'friendly', 'Print in a friendly way'
      option :friendly, type: :boolean, default: true
      desc 'print', 'Prints the certificate'
      def print(file)
        @data = if file.ends_with? 'request.txt'
                  MooTool::Models::RemoteRequest.load(file)
                else
                  MooTool::Models::RemoteResponse.load(file)
                end

        ap(@data)
      end
    end
  end
end
