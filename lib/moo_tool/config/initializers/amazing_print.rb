# frozen_string_literal: true

require 'amazing_print'

AmazingPrint.defaults = ({
  indent: 4, # Number of spaces for indenting.
  index: true, # Display array indices.
  html: false, # Use ANSI color codes rather than HTML.
  multiline: true, # Display in multiple lines.
  colors: :all, # Controls what should be colored. Can be one of :all, :values_only, or :none
  raw: false, # Do not recursively format instance variables.
  sort_keys: false,        # Do not sort hash keys.
  sort_vars: true,         # Sort instance variables.
  limit: false, # Limit arrays & hashes. Accepts bool or int.
  hash_format: :symbol, # The format for printing hashes. Can be one of :json, :rocket, or :symbol
  class_name: :class, # Method called to report the instance class name. (e.g. :to_s)
  object_id: true, # Show object id.
  color: {
    args: :whiteish,
    array: :white,
    bigdecimal: :blue,
    class: :yellow,
    date: :greenish,
    falseclass: :red,
    digest: :purple,
    uuid: :yellowish,
    integer: :blue,
    float: :blue,
    hash: :whiteish,
    keyword: :cyan,
    method: :purpleish,
    nilclass: :red,
    rational: :blue,
    string: :yellow,
    struct: :whiteish,
    symbol: :cyanish,
    time: :greenish,
    trueclass: :green,
    variable: :cyanish,
    path: :blue
  }
})
