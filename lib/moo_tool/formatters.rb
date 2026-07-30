module MooTool::Formatters
  def self.included(base)
    base.send :alias_method, :cast_without_formatters, :cast
    base.send :alias_method, :cast, :cast_with_formatters
  end

  def cast_with_formatters(object, type)
    cast = cast_without_formatters(object, type)

    case object
    when Pathname
      :path
    when UUIDTools::UUID
      :uuid
    when OpenSSL::PKey::EC::Point
      :point
    when MooTool::Models::FirmwareEntry
      :firmware_entry
    when MooTool::Models::Digest
      :digest
    when MooTool::Models::Certificate
      :certificate
    when MooTool::Models::ECCPublicKey
      :ecc_public_key
    when MooTool::Models::ECCSignature
      :ecc_signature
    when MooTool::Models::ECIESEncryption
      :ecc_encryption
    when :ALLOW_ANY_VALUE
      :any_value
    else
      cast
    end
  end

  def awesome_any_value(_input)
    colorize('*** SPLAT ***', :trueclass)
  end

  def awesome_path(object)
    colorize(object.to_s, :path)
  end

  def awesome_uuid(object)
    colorize(object.to_s, :uuid)
  end
end