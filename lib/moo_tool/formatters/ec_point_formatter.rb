module MooTool::Formatters::ECPointFormatter

  def awesome_point(point)
    point_data = point.to_octet_string(:uncompressed)[1..]
    x = point_data[0..(point_data.length / 2)].unpack1('H*').upcase
    y = point_data[(point_data.length / 2)..].unpack1('H*').upcase
    "#{colorize('ECCPoint',
                :class)} #{colorize(point.group.curve_name,
                                    :args)} #{colorize('x=',
                                                       :args)}#{colorize(x,
                                                                         :integer)}, #{colorize('y=',
                                                                                                :args)}#{colorize(
      y, :integer
    )}"
  end
end