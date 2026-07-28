# frozen_string_literal: true

module MooTool
  module Models
    class RemoteResponse
      MATCHER_REGEX = /---------RESPONSE START---------.*BODY:(?<body>.*)----------RESPONSE END----------/m

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

      def to_h
        { result: @result }
      end

      def inspect
        to_h.ai
      end
    end
  end
end
