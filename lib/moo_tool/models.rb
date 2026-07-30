# frozen_string_literal: true

module MooTool
  module Models
    def self.file_guesser(file)
      [Models::IMG4::File, Models::Certificate, Models::RemoteRequest, Models::RemoteResponse].each do |model|
        begin
          model.load(file)
        rescue Exception => e
          nil
        end
      end
    end
  end
end
