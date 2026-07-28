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
  end
end
