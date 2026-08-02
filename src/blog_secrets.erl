-module(blog_secrets).
-export([init/0, get_cookie_key/0, get_jwt_secret/0, get_register_token/0, get_super_admin_token/0]).

init() ->
  JWT = get_or_gen("JWT_SECRET"),
  Cookie = get_or_gen("COOKIE_SECRET"),
  SuperAdminToken = get_valid_super_admin_token(),
  RegisterToken = get_valid_register_token(),

  errm_http:set_secret(jwt_secret, JWT),
  errm_http:set_secret(cookie_key, Cookie),
  errm_http:set_secret(super_admin_token, SuperAdminToken),
  errm_http:set_secret(register_token, RegisterToken).


-spec get_cookie_key() -> {ok, term()} | {error, not_found}.
get_cookie_key() ->
  errm_http:get_secret(cookie_key).

-spec get_jwt_secret() -> {ok, term()} | {error, not_found}.
get_jwt_secret() ->
  errm_http:get_secret(jwt_secret).

-spec get_register_token() -> {ok, term()} | {error, not_found}.
get_register_token() ->
  errm_http:get_secret(register_token).

-spec get_super_admin_token() -> {ok, term()} | {error, not_found}.
get_super_admin_token() ->
  errm_http:get_secret(super_admin_token).

get_valid_register_token() ->
  case errm_env:get("REGISTER_TOKEN", "errm.env") of
    {ok, Token} ->
      case errm_env:get("REGISTER_TOKEN_EXPIRY", "errm.env") of
        {ok, ExpiryStr} ->
          Expiry = list_to_integer(ExpiryStr),
          Now = erlang:system_time(second),
          if Now > Expiry -> generate_register_token();
            true -> Token
          end;
        _ -> generate_register_token()
      end;
    _ -> generate_register_token()
  end.

get_valid_super_admin_token() ->
  case errm_env:get("SUPER_ADMIN_TOKEN", "errm.env") of
    {ok, Token} ->
      case errm_env:get("SUPER_ADMIN_TOKEN_EXPIRY", "errm.env") of
        {ok, ExpiryStr} ->
          Expiry = list_to_integer(ExpiryStr),
          Now = erlang:system_time(second),
          if Now > Expiry -> generate_super_admin_token();
             true -> Token
          end;
        _ -> generate_super_admin_token()
      end;
    _ -> generate_super_admin_token()
  end.

-spec get_or_gen(nonempty_string()) -> binary().
get_or_gen(Key) ->
  case os:getenv(Key) of
    false ->
      case errm_env:get(Key, "errm.env") of
        {ok, Value} -> debase64(Value);
        {error, not_found} -> 
          logger:error("No value found for key: ~p, generating", [Key]),
          gen(Key)
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


generate_register_token() ->
  Token = base64:encode(crypto:strong_rand_bytes(24), #{mode => 'urlsafe', padding => false}),
  Expiry = erlang:system_time(second) + 86400,  % 24 hours
  set_env_var("REGISTER_TOKEN", Token),
  set_env_var("REGISTER_TOKEN_EXPIRY", integer_to_list(Expiry)),
  Token.

generate_super_admin_token() ->
  Token = base64:encode(crypto:strong_rand_bytes(24), #{mode => 'urlsafe', padding => false}),
  Expiry = erlang:system_time(second) + 86400,  % 24 hours
  set_env_var("SUPER_ADMIN_TOKEN", Token),
  set_env_var("SUPER_ADMIN_TOKEN_EXPIRY", integer_to_list(Expiry)),
  Token.

set_env_var(Key, Value) ->
  KeyBin = list_to_binary(Key),
  ValBin = case Value of
             Bin when is_binary(Bin) -> Bin;
             Str -> list_to_binary(Str)
           end,
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

