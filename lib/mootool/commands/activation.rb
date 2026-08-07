# frozen_string_literal: true

module MooTool
  module Commands
    # CLI commands for interacting with Apple MobileActivation records.
    # These records are typically found in /System/Volumes/Hardware/MobileActivation.
    class Activation < Thor
      desc 'friendly', 'Print in a friendly way'
      option :friendly, type: :boolean, default: true
      desc 'print', 'Prints the certificate'
      # Parses and prints activation data from a file.
      #
      # Supports both RemoteRequest (files ending in 'request.txt') and RemoteResponse records.
      #
      # @param file [String] the path to the activation record file.
      # @return [void]
      # @example Print an activation request
      #   mootool activation print activation_request.txt
      def print(file)
        Models::CertificateIndex.load_default_certs
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
