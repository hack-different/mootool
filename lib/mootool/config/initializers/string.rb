# frozen_string_literal: true

class String
  def to_hex(upper: true)
    upper ? unpack1('H*').upcase : unpack1('H*')
  end

  def from_hex
    pack('H*')
  end
end
