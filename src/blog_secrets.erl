-module(blog_secrets).
-export([init/0, get_cookie_key/0, get_jwt_secret/0, get_register_token/0]).

init() ->
  JWT = get_or_gen("JWT_SECRET"),
  Cookie = get_or_gen("COOKIE_SECRET"),
  Token = get_or_gen("REGISTER_TOKEN"),

  errm_http:set_secret(jwt_secret, JWT),
  errm_http:set_secret(cookie_key, Cookie),
  errm_http:set_secret(register_token, Token).


-spec get_cookie_key() -> {ok, term()} | {error, not_found}.
get_cookie_key() ->
  errm_http:get_secret(cookie_key).

-spec get_jwt_secret() -> {ok, term()} | {error, not_found}.
get_jwt_secret() ->
  errm_http:get_secret(jwt_secret).

-spec get_register_token() -> {ok, term()} | {error, not_found}.
get_register_token() ->
  errm_http:get_secret(register_token).

-spec get_or_gen(nonempty_string()) -> binary().
get_or_gen(Key) ->
  case os:getenv(Key) of
    false ->
      case errm_env:get(Key, "errm.env") of
        {ok, Value} -> debase64(Value);
        {error, not_found} -> gen(Key)
      end;
    Value -> debase64(Value)
  end.

-spec debase64(string()) -> binary().
debase64(Val) ->
  base64:decode(Val, #{mode => urlsafe, padding => false}).

gen(Key) ->
  case Key of
    "JWT_SECRET"     -> gen_jwt_secret();
    "COOKIE_SECRET"  -> gen_cookie_secret();
    "REGISTER_TOKEN" -> gen_register_token();
    _ -> {error, unknown_key}
  end.


gen_jwt_secret() ->
  JWTSECRET = crypto:strong_rand_bytes(32),
  Base64 = base64:encode(JWTSECRET, #{mode => urlsafe, padding => false}),

  KEY = io_lib:format("JWT_SECRET=~s\n", [Base64]),
  file:write_file("errm.env", KEY, [append]),
  JWTSECRET.

gen_cookie_secret() ->
  COOKIESECRET = crypto:strong_rand_bytes(32),
  Base64 = base64:encode(COOKIESECRET, #{mode => urlsafe, padding => false}),
  KEY = io_lib:format("COOKIE_SECRET=~s\n", [Base64]),
  file:write_file("errm.env", KEY, [append]),
  COOKIESECRET.

gen_register_token() ->
  JwtSecret = get_jwt_secret(),
  Jwt = case JwtSecret of
    {ok, Bin} when is_binary(Bin) -> Bin;
    _ -> gen_jwt_secret()
  end,

  Token = case errm_jwt:sign(#{<<"sub">> => <<"register">>}, Jwt, hs256) of
    {ok, Tok} -> Tok;
    {error, Reason} -> error(Reason)
  end,

  Base64 = base64:encode(Token, #{mode => urlsafe, padding => false}),
  KEY = io_lib:format("REGISTER_TOKEN=~s\n", [Base64]),
  file:write_file("errm.env", KEY, [append]),
  Token.

