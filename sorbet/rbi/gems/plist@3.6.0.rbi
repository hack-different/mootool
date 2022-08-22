# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `plist` gem.
# Please instead update this file by running `bin/tapioca gem plist`.

class Array
  include ::Enumerable
  include ::Plist::Emit
end

class Hash
  include ::Enumerable
  include ::Plist::Emit
end

# Plist parses Mac OS X xml property list files into ruby data structures.
#
# === Load a plist file
# This is the main point of the library:
#
#   r = Plist.parse_xml(filename_or_xml)
module Plist
  class << self
    # Note that I don't use these two elements much:
    #
    #  + Date elements are returned as DateTime objects.
    #  + Data elements are implemented as Tempfiles
    #
    # Plist.parse_xml will blow up if it encounters a Date element.
    # If you encounter such an error, or if you have a Date element which
    # can't be parsed into a Time object, please create an issue
    # attaching your plist file at https://github.com/patsplat/plist/issues
    # so folks can implement the proper support.
    def parse_xml(filename_or_xml); end
  end
end

# === Create a plist
# You can dump an object to a plist in one of two ways:
#
# * <tt>Plist::Emit.dump(obj)</tt>
# * <tt>obj.to_plist</tt>
#   * This requires that you mixin the <tt>Plist::Emit</tt> module, which is already done for +Array+ and +Hash+.
#
# The following Ruby classes are converted into native plist types:
#   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time, true, false
# * +Array+ and +Hash+ are both recursive; their elements will be converted into plist nodes inside the <array> and <dict> containers (respectively).
# * +IO+ (and its descendants) and +StringIO+ objects are read from and their contents placed in a <data> element.
# * User classes may implement +to_plist_node+ to dictate how they should be serialized; otherwise the object will be passed to <tt>Marshal.dump</tt> and the result placed in a <data> element.
#
# For detailed usage instructions, refer to USAGE[link:files/docs/USAGE.html] and the methods documented below.
module Plist::Emit
  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
  def save_plist(filename, options = T.unsafe(nil)); end

  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.dump</tt> with +self+.
  def to_plist(envelope = T.unsafe(nil), options = T.unsafe(nil)); end

  class << self
    # The following Ruby classes are converted into native plist types:
    #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
    #
    # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
    #
    # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
    #
    # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
    def dump(obj, envelope = T.unsafe(nil), options = T.unsafe(nil)); end

    # Writes the serialized object's plist to the specified filename.
    def save_plist(obj, filename, options = T.unsafe(nil)); end

    def wrap(contents); end
  end
end

Plist::Emit::DEFAULT_INDENT = T.let(T.unsafe(nil), String)

class Plist::Emit::PlistBuilder
  # @return [PlistBuilder] a new instance of PlistBuilder
  def initialize(indent_str); end

  def build(element, level = T.unsafe(nil)); end

  private

  def comment_tag(content); end
  def data_tag(data, level); end
  def element_type(item); end
  def indent(str, level); end
  def tag(type, contents, level, &block); end
end

class Plist::Listener
  # @return [Listener] a new instance of Listener
  def initialize; end

  # include REXML::StreamListener
  def open; end

  # include REXML::StreamListener
  def open=(_arg0); end

  # include REXML::StreamListener
  def result; end

  # include REXML::StreamListener
  def result=(_arg0); end

  def tag_end(name); end
  def tag_start(name, attributes); end
  def text(contents); end
end

class Plist::PArray < ::Plist::PTag
  def to_ruby; end
end

class Plist::PData < ::Plist::PTag
  def to_ruby; end
end

class Plist::PDate < ::Plist::PTag
  def to_ruby; end
end

class Plist::PDict < ::Plist::PTag
  def to_ruby; end
end

class Plist::PFalse < ::Plist::PTag
  def to_ruby; end
end

class Plist::PInteger < ::Plist::PTag
  def to_ruby; end
end

class Plist::PKey < ::Plist::PTag
  def to_ruby; end
end

class Plist::PList < ::Plist::PTag
  def to_ruby; end
end

class Plist::PReal < ::Plist::PTag
  def to_ruby; end
end

class Plist::PString < ::Plist::PTag
  def to_ruby; end
end

class Plist::PTag
  # @return [PTag] a new instance of PTag
  def initialize; end

  # Returns the value of attribute children.
  def children; end

  # Sets the attribute children
  #
  # @param value the value to set the attribute children to.
  def children=(_arg0); end

  # Returns the value of attribute text.
  def text; end

  # Sets the attribute text
  #
  # @param value the value to set the attribute text to.
  def text=(_arg0); end

  def to_ruby; end

  class << self
    # @private
    def inherited(sub_class); end

    def mappings; end
  end
end

class Plist::PTrue < ::Plist::PTag
  def to_ruby; end
end

class Plist::StreamParser
  # @return [StreamParser] a new instance of StreamParser
  def initialize(plist_data_or_file, listener); end

  def parse; end

  private

  def parse_encoding_from_xml_declaration(xml_declaration); end
end

Plist::StreamParser::CDATA = T.let(T.unsafe(nil), Regexp)
Plist::StreamParser::COMMENT_END = T.let(T.unsafe(nil), Regexp)
Plist::StreamParser::COMMENT_START = T.let(T.unsafe(nil), Regexp)
Plist::StreamParser::DOCTYPE_PATTERN = T.let(T.unsafe(nil), Regexp)
Plist::StreamParser::TEXT = T.let(T.unsafe(nil), Regexp)
Plist::StreamParser::UNIMPLEMENTED_ERROR = T.let(T.unsafe(nil), String)
Plist::StreamParser::XMLDECL_PATTERN = T.let(T.unsafe(nil), Regexp)

# Raised when an element is not implemented
class Plist::UnimplementedElementError < ::RuntimeError; end

Plist::VERSION = T.let(T.unsafe(nil), String)
