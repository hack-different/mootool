# frozen_string_literal: true

# Extensions to the core String class for MooTool.
class String
  # Converts the binary string to its hexadecimal representation.
  #
  # @param upper [Boolean] whether to return uppercase hex (defaults to true)
  # @return [String] the hexadecimal string
  #
  # @example
  #   "\x00\xFF".to_hex #=> "00FF"
  def to_hex(upper: true)
    upper ? unpack1('H*').upcase : unpack1('H*')
  end

  # Converts the hexadecimal string to its binary representation.
  #
  # @return [String] the binary string
  #
  # @example
  #   "00FF".from_hex #=> "\x00\xFF"
  def from_hex
    pack('H*')
  end
end
