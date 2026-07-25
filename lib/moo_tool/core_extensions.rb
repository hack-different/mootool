# frozen_string_literal: true
# typed: true

# rubocop:disable Style/Documentation

class Integer
  def align(alignment = nil)
    alignment ||= 4

    return self if T.must(alignment) < 2

    alignment = T.must(alignment) - 1

    if nobits?(alignment)
      self
    else
      (self | alignment) + 1
    end
  end
end
