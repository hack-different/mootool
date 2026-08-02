# frozen_string_literal: true

class Integer
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

  def to_4cc(reverse: false)
    return self if self <= 65_535

    if reverse
      [to_s(16)].pack('H*').reverse.to_sym
    else
      [to_s(16)].pack('H*').to_sym
    end
  end
end
