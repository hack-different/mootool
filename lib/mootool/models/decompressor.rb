# frozen_string_literal: true

require 'lzfse'
require 'lzma'
require 'compress/lzss'

module MooTool
  # The magic Apple decompressor (as in it uses magics)
  class Decompressor
    COMPRESSION_LZSS = 'lzss'
    COMPRESSION_LZVN = 'lzvn'
    COMPRESSION_LZFSE = 'bvx2'
    COMPRESSION_LZMA = 'lzma'

    attr_reader :value

    def initialize(data)
      @value = case data[0..3]
               when COMPRESSION_LZFSE
                 LZFSE.lzfse_decompress(data)
               when COMPRESSION_LZVN
                 LZFSE.lzvn_decompress(data)
               when COMPRESSION_LZSS
                 Compress::LZSS.decompress(data)
               when COMPRESSION_LZMA
                 LZMA.decompress(data)
               else
                 data
               end
    end
  end
end
