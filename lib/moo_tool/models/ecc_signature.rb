
class MooTool::Models::ECCSignature
  include MooTool::Helpers::IMG4

  attr_reader :value

  def initialize(signature)
    @value = signature
    @values = construct(OpenSSL::ASN1.decode(signature))
    @r, @s = @values
  end

  def to_h
    { r: @r, s: @s }
  end

  def self.create(signature)
    size = signature.is_a?(MooTool::Models::Digest) ? signature.value.size : signature.size
    if size > 128
      # RSA Signature
      signature.hint = 'RSASignature' if signature.respond_to?(:hint)
      signature
    else
      value = signature.respond_to?(:value) ? signature.value : signature
      MooTool::Models::ECCSignature.new(value)
    end
  end
end

