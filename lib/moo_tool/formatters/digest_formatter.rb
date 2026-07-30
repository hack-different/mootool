module MooTool
  module Formatters
    module DigestFormatter
      def awesome_digest(object)
        files = object.files.map do |f|
          "#{' ' * @inspector.current_indentation}#{colorize('match', :args)}: #{colorize(f.fullname, :path)}"
        end
        formatted = if object.integer?
                      colorize(object.inspect, :integer)
                    elsif object.hint
                      properties = object.properties.any? ? " (#{object.properties.join(',')})" : ''
                      "#{colorize(object.hint, :class)}#{properties} #{colorize(object.inspect, :digest)}"
                    else
                      colorize(object.inspect, :digest).to_s
                    end

        if files.any?
          "#{formatted}\n#{files.join("\n")}"
        else
          formatted
        end
      end
    end
  end
end