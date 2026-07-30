class MooTool::Models::FirmwareEntry < MooTool::Models::PropertySequence
  def to_h
    { @key => self }
  end
end