module MooTool::Formatters::ECCEncryptionFormatter
  def awesome_ecc_encryption(encryption)
    values = encryption.to_h
    "#{colorize('ECIESEncryption',
                :class)} #{colorize(encryption.group,
                                    :args)} (x=#{colorize(values[:e_x],
                                                          :integer)}, y=#{colorize(values[:e_y],
                                                                                   :integer)}), n=#{colorize(
      values[:n], :integer
    )}"
  end
end