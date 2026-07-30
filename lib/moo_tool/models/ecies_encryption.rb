class MooTool::Models::ECIESEncryption
  include MooTool::Helpers::IMG4

  attr_reader :point, :nonce

  def initialize(input, nonce)
    # Recall that uncompressed points start with 0x04 to indicate that they are uncompressed
    # To get the proper X / Y we must trip this off first, then divide the string in half
    hex = input.to_octet_string(:uncompressed)[1..]
    pair = hex[0..(hex.length / 2)], hex[(hex.length / 2)..]
    @point = input
    @e_x = Models::Digest.create pair[0]
    @e_y = Models::Digest.create pair[1]

    @nonce = Models::Digest.create(nonce)
  end

  def self.from_der(data)
    OpenSSL::ASN1.decode(data)
  end

  def parse_point_any(point)
    mappings = %w[prime256v1 secp384r1].map do |group|
      group = OpenSSL::PKey::EC::Group.new(group)
      OpenSSL::PKey::EC::Point.new(group, point)
    rescue StandardError
      nil
    end

    mappings.compact.first
  end

  def group
    @point.group.curve_name
  end

  def to_h
    { e_x: @e_x.shasum, e_y: @e_y.shasum, n: @nonce.shasum }
  end

  def inspect
    to_h.ai
  end
end