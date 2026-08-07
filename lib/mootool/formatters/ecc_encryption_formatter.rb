# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatters for ECC encryption related data.
    module ECCEncryptionFormatter
      # Formats an ECIES encryption object by displaying its curve, coordinates, and nonce.
      #
      # @param encryption [MooTool::Models::ECIESEncryption] the encryption object to format
      # @return [String] the colorized string representation
      def awesome_ecc_encryption(encryption)
        values = encryption.to_h
        "#{colorize('ECIESEncryption',
                    :class)} #{colorize(encryption.group,
                                        :args)} (x=#{colorize(values[:e_x],
                                                              :integer)}, y=#{colorize(values[:e_y],
                                                                                       :integer)}), n=#{colorize(
                                                                                         values[:n], :integer
                                                                                       )}"
      end
    end
  end
end
