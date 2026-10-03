-module(blog_secrets).
-export([init/0, get_cookie_key/0, get_jwt_secret/0, get_register_token/0, get_super_admin_token/0, generate_register_token/0, gen_jwt_secret/0, gen_cookie_secret/0]).

init() ->
  get_or_gen("JWT_SECRET"),
  get_or_gen("COOKIE_SECRET"),

  get_valid_super_admin_token(),
  get_valid_register_token().

-spec get_cookie_key() -> {ok, term()} | {error, not_found}.
get_cookie_key() ->
  case errm_http:get_secret(cookie_key) of
    {error, not_found} ->
      get_or_gen("COOKIE_SECRET"),
      get_cookie_key();
    {ok, Value} -> {ok, Value}
  end.

-spec get_jwt_secret() -> {ok, term()} | {error, not_found}.
get_jwt_secret() ->
  case errm_http:get_secret(jwt_secret) of
    {error, not_found} ->
      get_or_gen("JWT_SECRET"),
      get_jwt_secret();
    {ok, Value} -> {ok, Value}
  end.

-spec get_register_token() -> {ok, term()} | {error, not_found}.
get_register_token() -> get_token("REGISTER", register_token).

-spec get_super_admin_token() -> {ok, term()} | {error, not_found}.
get_super_admin_token() -> get_token("SUPER_ADMIN", super_admin_token).


get_token(Prefix, SecretKey) ->
  Now = erlang:system_time(second),
  case errm_http:get_secret(SecretKey) of
    {ok, {Token, Expiry}} when Expiry > Now ->
      {ok, Token};
    _ ->
      generate_token(Prefix, SecretKey),
      get_token(Prefix, SecretKey)
  end.

get_valid_register_token() -> get_valid_token("REGISTER", register_token).

get_valid_super_admin_token() -> get_valid_token("SUPER_ADMIN", super_admin_token).

get_valid_token(Prefix, SecretKey) ->
  Now = erlang:system_time(second),
  case token_and_expiry(Prefix ++ "_TOKEN", Prefix ++ "_TOKEN_EXPIRY") of
    {ok, Token, Expiry} when Expiry > Now ->
      errm_http:set_secret(SecretKey, {Token, Expiry}),
      ok;
    _ ->
      generate_token(Prefix, SecretKey)
  end.

-spec get_or_gen(nonempty_string()) -> ok.
get_or_gen(Key) ->
  case env_get(Key) of
    {ok, Value} ->
      errm_http:set_secret(secret_key(Key), debase64(Value)),
      ok;
    _ ->
      gen(Key)
  end.

-spec debase64(string()) -> binary().
debase64(Val) ->
  base64:decode(Val, #{mode => urlsafe, padding => false}).

gen(Key) ->
  case Key of
    "JWT_SECRET"     -> gen_jwt_secret();
    "COOKIE_SECRET"  -> gen_cookie_secret();
    _ -> {error, unknown_key}
  end.

gen_jwt_secret() ->
  Secret = crypto:strong_rand_bytes(32),
  Base64 = base64:encode(Secret, #{mode => urlsafe, padding => false}),

  set_env_var("JWT_SECRET", Base64),
  errm_http:set_secret(jwt_secret, Secret),
  ok.

gen_cookie_secret() ->
  Secret = crypto:strong_rand_bytes(32),
  Base64 = base64:encode(Secret, #{mode => urlsafe, padding => false}),

  set_env_var("COOKIE_SECRET", Base64),
  errm_http:set_secret(cookie_key, Secret),
  ok.

generate_register_token() -> generate_token("REGISTER", register_token).

generate_token(Prefix, SecretKey) ->
  Token = binary_to_list(base64:encode(crypto:strong_rand_bytes(24), #{mode => urlsafe, padding => false})),
  Expiry = erlang:system_time(second) + 86400,
  set_env_var(Prefix ++ "_TOKEN", Token),
  set_env_var(Prefix ++ "_TOKEN_EXPIRY", integer_to_list(Expiry)),
  errm_http:set_secret(SecretKey, {Token, Expiry}),
  ok.

token_and_expiry(TokenKey, ExpiryKey) ->
  case env_get(TokenKey) of
    {ok, Token} ->
      case env_get(ExpiryKey) of
        {ok, ExpiryStr} -> {ok, Token, list_to_integer(ExpiryStr)};
         _              -> {error, not_found}
      end;
    _ -> {error, not_found}
  end.

env_get(Key) ->
  case os:getenv(Key) of
    false -> errm_env:get(Key, "errm.env");
    Value -> {ok, Value}
  end.

set_env_var(Key, Value) ->
  KeyBin = list_to_binary(Key),
  ValBin = case Value of
    Bin when is_binary(Bin) -> Bin;
    Str -> list_to_binary(Str)
  end,
  os:putenv(Key, binary_to_list(ValBin)),
  NewLine = <<KeyBin/binary, "=", ValBin/binary, "\n">>,
  case file:read_file("errm.env") of
    {ok, Content} ->
      Lines = binary:split(Content, <<"\n">>, [global]),
      Filtered = [L || L <- Lines,
        L =/= <<>>,
        case binary:match(L, <<KeyBin/binary, "=">>) of
          {0, _} -> false;
          _      -> true
      end],
      NewContent = binary:join(Filtered ++ [NewLine], <<"\n">>),
      file:write_file("errm.env", NewContent);
    {error, enoent} ->
      file:write_file("errm.env", NewLine)
  end.


secret_key("JWT_SECRET") -> jwt_secret;
secret_key("COOKIE_SECRET") -> cookie_key;
secret_key(_) -> error.
