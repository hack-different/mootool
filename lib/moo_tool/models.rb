# frozen_string_literal: true

module MooTool
  module Models
    extend ActiveSupport::Autoload

    autoload :IMG4
    autoload :Certificate
    autoload :ShaSum
    autoload :Digest
    autoload :FileIndex
    autoload :RemoteRequest
    autoload :RemoteResponse
    autoload :IOReg

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
