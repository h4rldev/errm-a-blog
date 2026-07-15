-module(blog_middlewares).
-export([get/0]).

get() ->
  CompressionConfig = #{
    preferred => [zstd, brotli, gzip, deflate],
    compression_level => 9,
    min_length => 1 bsl 20
  },

  DecompressionConfig = #{
    allowed => [zstd, brotli, gzip, deflate]
  },

  [
    errm_http_compress:compress(CompressionConfig),
    errm_http_compress:decompress(DecompressionConfig)
  ].
