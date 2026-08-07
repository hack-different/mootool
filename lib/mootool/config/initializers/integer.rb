# frozen_string_literal: true

# Extensions to the core Integer class for MooTool.
class Integer
  # Aligns the integer to the specified boundary.
  #
  # @param alignment [Integer, nil] the boundary to align to (defaults to 4)
  # @return [Integer] the aligned integer
  #
  # @example
  #   7.align(4) #=> 8
  #   8.align(4) #=> 8
  def align(alignment = nil)
    alignment ||= 4

    return self if alignment < 2

    alignment -= 1

    if nobits?(alignment)
      self
    else
      (self | alignment) + 1
    end
  end

  # Converts the integer to a 4-character code (4CC) symbol.
  #
  # @param reverse [Boolean] whether to reverse the byte order
  # @return [Symbol, Integer] the 4CC symbol, or the integer if it's too small
  #
  # @example
  #   0x61626364.to_4cc #=> :abcd
  def to_4cc(reverse: false)
    return self if self <= 65_535

    if reverse
      [to_s(16)].pack('H*').reverse.to_sym
    else
      [to_s(16)].pack('H*').to_sym
    end
  end
end
