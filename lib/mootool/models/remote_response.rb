# frozen_string_literal: true

module MooTool
  module Models
    # Models responses from certification services.
    # Parses response files containing certificates.
    class RemoteResponse
      # Regex to extract the body from a standard response wrapper.
      MATCHER_REGEX = /---------RESPONSE START---------.*BODY:(?<body>.*)----------RESPONSE END----------/m

      # Loads a remote response from a file and parses any certificates within.
      #
      # @param file [String] The path to the response file.
      # @return [Array<::MooTool::Models::Certificate>, nil] A list of parsed certificates or nil.
      def self.load(file)
        raw_data = File.read(file)

        body = raw_data.match(MATCHER_REGEX).named_captures['body']

        @result = case body
                  when /-----BEGIN CERTIFICATE-----/
                    body.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |text|
                      ::MooTool::Models::Certificate.new OpenSSL::X509::Certificate.new(text)
                    end
                  end
      end

      # Converts the response to a hash representation.
      #
      # @return [Hash] A hash containing the result.
      def to_h
        { result: @result }
      end

      # Returns a string representation of the response for debugging.
      #
      # @return [String] The inspected hash.
      def inspect
        to_h.ai
      end
    end
  end
end
