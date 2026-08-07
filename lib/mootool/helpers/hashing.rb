# frozen_string_literal: true

module MooTool
  module Helpers
    # Helper functions for generating SHA-384 hashes from data
    #
    # This module provides utilities to convert raw data or a list of raw data entries
    # into {Models::Digest} objects using SHA-384.
    module Hashing
      extend ActiveSupport::Concern

      # Converts data to a SHA-384 Digest object
      #
      # @param data [String, nil] The data to hash.
      # @return [Models::Digest, nil] The resulting Digest object, or nil if data was nil.
      def to_hash(data)
        return nil if data.nil?

        Models::Digest.create(::Digest::SHA384.digest(data))
      end

      # Computes hashes for all entries in #raw_hashes
      #
      # @return [Array<Models::Digest>] List of computed Digest objects.
      def hashes
        raw_hashes.map do |entry|
          to_hash(entry[:value])
        end
      end

      # Computes named hashes for all entries in #raw_hashes
      #
      # @return [Hash{Symbol => Models::Digest}] Hash mapping entry kind to its Digest object.
      def named_hashes
        raw_hashes.map do |entry|
          { entry[:kind] => to_hash(entry[:value]) }
        end.reduce({}, :merge)
      end
    end
  end
end
