# frozen_string_literal: true

module MooTool
  module Helpers
    # Helper functions for generating hashes
    module Hashing
      extend ActiveSupport::Concern

      def to_hash(data)
        return nil if data.nil?

        Models::Digest.create(::Digest::SHA384.digest(data))
      end

      def hashes
        raw_hashes.map do |entry|
          to_hash(entry[:value])
        end
      end

      def named_hashes
        raw_hashes.map do |entry|
          { entry[:kind] => to_hash(entry[:value]) }
        end.reduce({}, :merge)
      end
    end
  end
end
