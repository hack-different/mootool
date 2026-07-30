module MooTool::Formatters::ECPublicKey
  def awesome_ecc_public_key(public_key)
    point_data = public_key.point.to_octet_string(:uncompressed)[1..]
    x = point_data[0..(point_data.length / 2)].unpack1('H*').upcase
    y = point_data[(point_data.length / 2)..].unpack1('H*').upcase
    "#{colorize('ECCPublicKey',
                :class)} #{colorize(public_key.curve.curve_name,
                                    :args)} #{colorize('x=',
                                                       :args)}#{colorize(x,
                                                                         :integer)}, #{colorize('y=',
                                                                                                :args)}#{colorize(
      y, :integer
    )}"
  end

end