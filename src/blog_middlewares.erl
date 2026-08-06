-module(blog_middlewares).
-export([get/0, auth_middleware/3, get_user_id/1, get_claims/1, authenticate/1, is_super_admin/1, is_admin/1]).

get() ->
  CompressionConfig = #{
    preferred => [zstd, brotli, gzip, deflate],
    compression_level => 9,
    min_length => 1 bsl 20
  },

  DecompressionConfig = #{
    allowed => [zstd, brotli, gzip, deflate]
  },

  CORS = errm_http_cors:make(#{
    policies => [
      #{
        origin => ["http://localhost:5173", "http://localhost", "http://127.0.0.1:5173", "http://127.0.0.1"],
        methods => [get, post, put, delete, patch, options],
        headers => ["Content-Type", "Authorization", "Accept", "Origin"],
        credentials => true,
        max_age => 86400
      }
    ]
  }),

  ProtectedPrefixes = [
    ["api"]
  ],

  RoleProtectedPrefixes = [
    {[<<"admin">>], [<<"administrator">>, <<"super-administrator">>]},
    {[<<"api">>, <<"admin">>], [<<"administrator">>, <<"super-administrator">>]}
  ],

  PublicRoutes = [
    {get, ["api", "posts"]},
    {get, ["api", "post", ':*']},
    {get, ["api", "tags"]},

    {post, ["api", "guestbook"]},
    {post, ["api", "auth", "register"]},
    {post, ["api", "auth", "login"]},

    {post, ["api", "post", ':post_id', "comments"]},
    {get, ["ws"]}
  ],

  [
   errm_http_compress:compress(CompressionConfig),
   CORS,
   errm_http_cookie:with_cookies(),
   auth_middleware(ProtectedPrefixes, RoleProtectedPrefixes, PublicRoutes),
   errm_http_compress:decompress(DecompressionConfig)
  ].


-spec auth_middleware(ProtectedPrefixes :: [[binary() | string()]], RoleProtectedPrefixes :: [{[binary()], [binary()]}], PublicRoutes :: [{errm_http:method(), [binary() | string() | atom()]}]) -> errm_http:middleware().
auth_middleware(ProtectedPrefixes, RoleProtectedPrefixes, PublicRoutes) ->
  NormalizedPrefixes = [normalize_prefix(P) || P <- ProtectedPrefixes],
  fun(Req, Next) ->
    Method = maps:get(method, Req, get),
    Path = maps:get(path, Req, <<"/">>),
    Segments = to_segments(Path),

    case role_required(Segments, RoleProtectedPrefixes) of
      {ok, AllowedRoles} ->
        case authenticate(Req) of
          {ok, UserId, Claims} ->
            case lists:member(maps:get(<<"role">>, Claims, undefined), AllowedRoles) of
              true -> Next(Req#{user_id => UserId, claims => Claims});
              false -> response_utils:error(403, "Forbidden")
            end;
          {error, _Reason} ->
            response_utils:error(401, "Unauthorized")
        end;
      none ->
        case is_protected(Segments, NormalizedPrefixes) of
          false ->
            Next(Req);
          true ->
            case is_public_with_segments(Method, Segments, PublicRoutes) of
              true ->
                Next(Req);
              false ->
                case authenticate(Req) of
                  {ok, UserId, Claims} ->
                    Req1 = Req#{
                      user_id => UserId,
                      claims => Claims
                    },
                    Next(Req1);
                  {error, _Reason} ->
                    logger:error("Unauthorized: ~p", [_Reason]),
                    response_utils:error(401, "Unauthorized")
                end
            end
        end
    end
  end.

-spec is_super_admin(errm_http:request()) -> boolean().
  is_super_admin(Req) ->
    case get_claims(Req) of
      undefined -> false;
      Claims ->
        case maps:get(<<"role">>, Claims, undefined) of
          undefined -> false;
          <<"super-administrator">> -> true;
          _ -> false
        end
    end.

-spec is_admin(errm_http:request()) -> boolean().
  is_admin(Req) ->
    case get_claims(Req) of
      undefined -> false;
      Claims -> 
        case maps:get(<<"role">>, Claims, undefined) of
          undefined -> false;
          <<"super-administrator">> -> true;
          <<"administrator">> -> true;
          _ -> false
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
  CookieKey = blog_secrets:get_cookie_key(),
  JwtSecret = blog_secrets:get_jwt_secret(),

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
        UserId -> 
          logger:debug("JWT validated successfully, got user id ~p", [UserId]),
          {ok, UserId, Claims}
      end;
    {error, Reason} -> {error, {invalid_token, Reason}}
  end.


-spec is_protected([binary()], [[binary()]]) -> boolean().
is_protected(_Segments, []) -> false;
is_protected(Segments, [Prefix | Rest]) ->
    starts_with(Prefix, Segments) orelse is_protected(Segments, Rest).

-spec starts_with([binary()], [binary()]) -> boolean().
starts_with([], _) -> true;
starts_with([_ | _], []) -> false;
starts_with([H | T], [SH | ST]) ->
    H =:= SH andalso starts_with(T, ST).

-spec normalize_prefix([binary() | string() | atom()]) -> [binary()].
normalize_prefix(Prefix) ->
    [normalize_binary_segment(S) || S <- Prefix].

-spec normalize_binary_segment(binary() | string() | atom()) -> binary().
normalize_binary_segment(Seg) when is_binary(Seg) -> Seg;
normalize_binary_segment(Seg) when is_list(Seg) ->
    list_to_binary(Seg);
normalize_binary_segment(Seg) when is_atom(Seg) ->
    atom_to_binary(Seg, utf8).



-spec is_public_with_segments(errm_http:method(), [binary()],
                              [{errm_http:method(), [binary() | string() | atom()]}]) -> boolean().
is_public_with_segments(Method, Segments, PublicRoutes) ->
    lists:any(fun({PubMethod, PubPattern}) ->
        PubMethod =:= Method andalso matches(normalize_pattern(PubPattern), Segments)
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
        ":" ++ _ -> ':placeholder';
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

role_required(_Segments, []) -> none;
role_required(Segments, [{Prefix, Roles} | Rest]) ->
  case starts_with(Prefix, Segments) of
    true -> {ok, Roles};
    false -> role_required(Segments, Rest)
  end.
