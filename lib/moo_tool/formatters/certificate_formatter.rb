module MooTool::Formatters::CertificateFormatter
  def awesome_certificate(object)
    awesome_hash(object.to_h)
  end
end