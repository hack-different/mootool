# frozen_string_literal: true

module MooTool
  module Formatters
    # Formatter for ECC public keys.
    module ECPublicKey
      # Formats an ECC public key by displaying its curve name and coordinates.
      #
      # @param public_key [MooTool::Models::ECCPublicKey] the public key to format
      # @return [String] the colorized string representation
      def awesome_ecc_public_key(public_key)
        point_data = public_key.point.to_octet_string(:uncompressed)[1..]
        x = point_data[0..(point_data.length / 2)].unpack1('H*').upcase
        y = point_data[(point_data.length / 2)..].unpack1('H*').upcase
        "#{colorize('ECCPublicKey',
                    :class)} #{colorize(public_key.curve.curve_name,
                                        :args)} #{colorize('x=',
                                                           :args)}#{colorize(x,
                                                                             :integer)}, #{colorize('y=',
                                                                                                    :args)}#{colorize(
                                                                                                      y, :integer
                                                                                                    )}"
      end
    end
  end
end
