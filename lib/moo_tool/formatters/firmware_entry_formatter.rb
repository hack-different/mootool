module MooTool::Formatters::FirmwareEntryFormatter

  def awesome_firmware_entry(entry, _options = {})
    values = entry.value
    digest = values[:DGST]
    values.delete(:DGST)
    booleans = values.select { |_k, v| [true, false].include?(v) }.map do |key, value|
      color = value ? :trueclass : :falseclass
      colorize(key, color).to_s
    end
    other = values.reject { |_k, v| [true, false].include?(v) }

    results = ["#{colorize('Firmware', :class)} #{booleans.join(' ')} #{colorize(digest.shasum, :digest)}"]
    results += digest.files.map do |file|
      "#{' ' * @inspector.current_indentation}                          #{colorize('match',
                                                                                   :args)}: #{colorize(
        file.fullname, :path
      )}"
    end

    if other.any?
      results += other.map do |key, value|
        case value
        when MooTool::Models::Digest

          "#{' ' * @inspector.current_indentation}      #{colorize(key,
                                                                   :symbol)}  #{colorize(value.hint,
                                                                                         :class).rjust(24)} #{colorize(
            value.shasum, :digest
          )}"
        else
          "#{' ' * @inspector.current_indentation}  #{colorize(key, :symbol)}: #{value.ai}"
        end
      end
    end

    results.join("\n")
  end

end