-module(auth_api).
-export([register/1, login/1]).

-spec register(errm_http:request()) -> {ok, errm_http:response()}.
register(Req) ->
  case validate_register_request(Req) of
    {error, Status, Message} -> response_utils:error(Status, Message);
    {ok, Username, Password, RegisterToken} ->
      handle_registration(Username, Password, RegisterToken)
  end.


-spec login(errm_http:request()) -> {ok, errm_http:response()}.
login(Req) ->
  case validate_login_request(Req) of
    {error, Status, Message} -> response_utils:error(Status, Message);
    {ok, Username, Password} ->
      handle_login(Username, Password)
  end.


validate_register_request(Req) ->
  case maps:get(headers, Req, #{}) of
    #{<<"content-type">> := <<"application/json">>} ->
      case maps:get(body, Req, <<>>) of
        <<>> -> {error, 400, "No body provided"};
        Body ->
          case errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Username = get_from_json("username", Data),
              Password = get_from_json("password", Data),
              RegisterToken = get_from_json("register_token", Data),
              case {Username, Password, RegisterToken} of
                {undefined, _, _} -> {error, 400, "No username provided"};
                {_, undefined, _} -> {error, 400, "No password provided"};
                {_, _, undefined} -> {error, 400, "No register token provided"};
                {U, P, R} when is_list(U), is_list(P), is_list(R) -> {ok, U, P, R};
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error creating reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.

handle_registration(Username, Password, RegisterToken) ->
  case blog_secrets:get_register_token() of
    {error, not_found} ->
      logger:error("No register token found in secrets"),
      response_utils:error(500, "Registration temporarily unavailable");
    {ok, Token} when Token =:= RegisterToken ->
      create_user(Username, Password);
    {ok, Token} ->
      logger:error("Invalid register token, expected ~p, got ~p", [Token, RegisterToken]),
      response_utils:error(400, "Invalid register token")
  end.

create_user(Username, Password) ->
  case blog_db:db() of
    {error, Reason1} ->
      logger:error("Error opening database: ~p", [Reason1]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      case errm_argon:hash(Password, interactive) of
        {error, Reason2} ->
          logger:error("Error hashing password: ~p", [Reason2]),
          response_utils:error(500, "Password processing error");
        {ok, Hash} ->
          Uuid = errm_uuid:to_string(errm_uuid:v7()),
          insert_user(Db, Uuid, Username, Hash)
      end
  end.

insert_user(Db, Uuid, Username, Hash) ->
  Sql = "INSERT INTO users (uuid, username, password_hash, role) VALUES ($1, $2, $3, $4)",
  case errm_sqlite:query(Db, Sql, [list_to_binary(Uuid), list_to_binary(Username), Hash, <<"poster">>]) of
    {ok, _} ->
      Message = io_lib:format("Account ~s (~s) created successfully!", [Username, Uuid]),
      MessageBin = iolist_to_binary(Message),
      response_utils:ok(#{message => MessageBin});
    {error, Reason} ->
      logger:error("Error creating account: ~p", [Reason]),
      response_utils:error(500, "Error creating account")
  end.


validate_login_request(Req) ->
  case maps:get(headers, Req, #{}) of
    #{<<"content-type">> := <<"application/json">>} ->
      case maps:get(body, Req, <<>>) of
        <<>> -> {error, 400, "No body provided"};
        Body ->
          case errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Username = get_from_json("username", Data),
              Password = get_from_json("password", Data),
              case {Username, Password} of
                {undefined, _} -> {error, 400, "No username provided"};
                {_, undefined} -> {error, 400, "No password provided"};
                {U, P} when is_list(U), is_list(P) -> {ok, U, P};
                _ -> {error, 400, "Invalid JSON fields"}
              end;
            {error, Reason} ->
              logger:error("Error creating reading json: ~p", [Reason]),
              {error, 400, "Invalid JSON"}
          end
      end;
    _ -> {error, 400, "Invalid content type"}
  end.

handle_login(Username, Password) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      fetch_user_hash(Db, Username, Password)
  end.

fetch_user_hash(Db, Username, Password) ->
  Sql = "SELECT uuid, password_hash, role FROM users WHERE username = ? LIMIT 1",
  case errm_sqlite:query(Db, Sql, [list_to_binary(Username)]) of
    {ok, []} ->
      response_utils:error(400, "User not found");
    {ok, [Row]} ->
      UserId = maps:get("uuid", Row),
      StoredHash = maps:get("password_hash", Row),
      StoredHash1 = list_to_binary(io_lib:format("~s", [StoredHash])),
      Role = maps:get("role", Row),
      case errm_argon:verify(Password, StoredHash1) of
        true ->
          issue_session_token(UserId, Role);
        false ->
          response_utils:error(400, "Invalid credentials")
      end;
    {error, Reason1} ->
      logger:error("Error fetching user: ~p", [Reason1]),
      response_utils:error(500, "Database error")
  end.

issue_session_token(UserId, Role) ->
  Claims = #{<<"sub">> => UserId, <<"role">> => Role},
  case blog_secrets:get_jwt_secret() of
    {ok, Secret} when is_binary(Secret) ->
      case errm_jwt:sign(Claims, Secret, hs256, #{ttl => 86400 * 30}) of
        {ok, Token} ->
          set_session_cookie(Token);
        {error, Reason} ->
          logger:error("Error signing JWT: ~p", [Reason]),
          response_utils:error(500, "Temporary login error")
      end;
    _ -> response_utils:error(500, "Temporary login error")
  end.

set_session_cookie(Token) ->
  CookieName = <<"session">>,
  CookieOpts = #{
    path => <<"/">>,
    http_only => true,
    secure => true,
    same_site => lax,
    max_age => 30 * 86400   % match JWT TTL
  },
  Jar0 = errm_http_cookie_jar:new(),
  Jar1 = errm_http_cookie_jar:put(Jar0, CookieName, Token, CookieOpts),

  case blog_secrets:get_cookie_key() of
    {ok, Key} when is_binary(Key) ->
      CookieHeaders = errm_http_cookie_jar:to_headers(Jar1, Key),
      {ok, {Status, Headers, Body}} = response_utils:ok(#{message => <<"Login successful">>}),
      FinalResponse = errm_http_cookie:add_cookies({Status, Headers, Body}, CookieHeaders),
      {ok, FinalResponse};
    {error, Reason} ->
      logger:error("Error getting cookie key: ~p", [Reason]),
      response_utils:error(500, "Temporary login error")
  end.


get_from_json(Key, Data) ->
  KeyBin = list_to_binary(Key),
  case maps:is_key(KeyBin, Data) of
    true -> binary_to_list(maps:get(KeyBin, Data));
    _ -> {error, missing_key}
  end.

