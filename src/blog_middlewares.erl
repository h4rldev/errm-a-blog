-module(blog_middlewares).
-export([get/0, auth_middleware/1, get_user_id/1, get_claims/1]).

get() ->
  CompressionConfig = #{
    preferred => [zstd, brotli, gzip, deflate],
    compression_level => 9,
    min_length => 1 bsl 20
  },

  DecompressionConfig = #{
    allowed => [zstd, brotli, gzip, deflate]
  },

  PublicRoutes = [
    {get, ["api", "posts"]},
    {get, ["api", "posts", ':*']},

    {post, ["api", "auth", "register"]},
    {post, ["api", "auth", "login"]}
  ],

  [
   errm_http_compress:compress(CompressionConfig),
   errm_http_cookie:with_cookies(),
   auth_middleware(PublicRoutes),
   errm_http_compress:decompress(DecompressionConfig)
  ].


-spec auth_middleware([{errm_http:method(), [binary() | string() | atom()]}]) -> errm_http:middleware().
auth_middleware(PublicRoutes) ->
  fun(Req, Next) ->
      Method = maps:get(method, Req, get),
      Path = maps:get(path, Req, <<"/">>),
      case is_public(Method, Path, PublicRoutes) of
        true ->
          Next(Req);
        false ->
          case authenticate(Req) of
            {ok, UserId, Claims} ->
              Req1 = Req#{
                uuid => UserId,
                claims => Claims
              },
              Next(Req1);
            {error, _Reason} ->
              response_utils:error(401, "Unauthorized")
          end
      end
  end.

-spec get_user_id(errm_http:request()) -> binary() | undefined.
get_user_id(Req) ->
  maps:get(user_id, Req, undefined).

-spec get_claims(errm_http:request()) -> map() | undefined.
get_claims(Req) ->
  maps:get(claims, Req, undefined).


-spec authenticate(errm_http:request()) -> {ok, binary(), map()} | {error, term()}.
authenticate(Req) ->
  CookieKey = blog_config:get(cookie_key),
  JwtSecret = blog_config:get(jwt_secret),

  case {CookieKey, JwtSecret} of
    {{ok, Key}, {ok, Secret}} when is_binary(Key), is_binary(Secret) ->
      Jar = errm_http_cookie_jar:from_request(Req, Key),
      case errm_http_cookie_jar:get(Jar, <<"session">>) of
        undefined -> {error, missing_cookie};
        Token ->
          verify_jwt(Token, Secret)
      end;
    _ -> {error, missing_cookie_or_jwt_secret}
  end.


verify_jwt(Token, Secret) ->
  case errm_jwt:verify(Token, Secret, hs256) of
    {ok, Claims} ->
      case maps:get(<<"sub">>, Claims, undefined) of
        undefined -> {error, missing_sub};
        UserId -> {ok, UserId, Claims}
      end;
    {error, Reason} -> {error, {invalid_token, Reason}}
  end.


is_public(Method, Path, PublicRoutes) ->
  Segments = to_segments(Path),
  lists:any(fun({PubMethod, PubPattern}) ->
    Normalized = normalize_pattern(PubPattern),
    Match = PubMethod =:= Method andalso matches(Normalized, Segments),
    Match
  end, PublicRoutes).


-spec to_segments(binary() | [binary() | unicode:chardata()]) -> [binary()].
to_segments(Path) when is_binary(Path) ->
  binary:split(Path, <<"/">>, [global, trim_all]);
to_segments(Path) when is_list(Path) ->
  [if is_binary(S) -> S; is_list(S) -> list_to_binary(S) end || S <- Path].


normalize_pattern(Pattern) ->
  [normalize_segment(S) || S <- Pattern].

normalize_segment(Seg) when is_binary(Seg) -> Seg;
normalize_segment(Seg) when is_list(Seg) ->
  case Seg of
    ":*" -> ':*';
    ":" ++ _ -> ':placeholder';   % any single‑segment placeholder
    _ -> list_to_binary(Seg)
  end;
normalize_segment(Seg) when is_atom(Seg) ->
  case Seg of
    ':*' -> ':*';
    _ -> ':placeholder'
  end.


-spec matches([binary() | atom()], [binary()]) -> boolean().
matches([], []) -> true;
matches([], _) -> false;
matches([':*' | _], _) -> true;
matches([_ | _], []) -> false;
matches([H | T], [_SH | ST]) when is_atom(H) ->
  matches(T, ST);
matches([H | T], [SH | ST]) when is_binary(H) ->
  case H =:= SH of
    true -> matches(T, ST);
    false -> false
  end.
