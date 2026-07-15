-module(auth_api).
-export([register/1, login/1]).


-spec register(errm_http:request()) -> {ok, errm_http:response()}.
register(Req) ->
  Headers = maps:get(headers, Req, #{}),
  case maps:get(<<"content-type">>, Headers, undefined) of
    <<"application/json">> ->
      Body = maps:get(body, Req, <<>>),
      case Body of
        <<>> -> response_utils:error(400, "No body provided");
        _ ->
          try errm_json:decode(Body) of
            {ok, Data} when is_map(Data) ->
              Username = get_from_json(<<"username">>, Data),
              case Username of
                undefined -> response_utils:error(400, "No username provided")
              end,

              Password = case get_from_json(<<"password">>, Data) of
                {ok, Pass} -> Pass
              end,

              ReceivedRegisterToken = get_from_json(<<"register_token">>, Data),
              case ReceivedRegisterToken of
                {ok, RegToken} -> RegToken
              end,

              DecodedRegisterToken = base64:decode(ReceivedRegisterToken, #{mode => urlsafe, padding => false}),
              RegisterToken = blog_secrets:get_register_token(),

              logger:debug("DecodedRegisterToken: ~p", [DecodedRegisterToken]),
              logger:debug("RegisterToken: ~p", [RegisterToken]),
              case DecodedRegisterToken of
                DecRegToken when DecRegToken =/= RegisterToken ->
                  response_utils:error(400, "Invalid register token")
              end,

              Db = blog_db:db(),
              case errm_sqlite:query(Db, "SELECT * FROM users WHERE username = $1", [Username]) of
                {ok, []} ->
                  response_utils:error(400, "User already exists.")
              end,

              Hash = case hash_password_async(Password) of
                {ok, Hsh} -> Hsh;
                {error, timeout} -> response_utils:error(500, "Timeout when hashing password")
              end,

              case errm_sqlite:query(Db, "INSERT INTO users (username, password_hash, role) VALUES ($1, $2)", [Username, Hash, <<"poster">>]) of
                {ok, _} -> response_utils:ok(#{message => <<"Created account!">>});
                {error, Reason} ->
                  logger:error("Error creating account: ~p", [Reason]),
                  response_utils:error(500, "Error creating account")
              end;
            {error, _} ->
              response_utils:error(400, "Invalid JSON")
          catch
            _:_ -> response_utils:error(400, "Invalid JSON")
          end
      end;
    _ -> response_utils:error(400, "Invalid content type")
  end.

-spec login(errm_http:request()) -> {ok, errm_http:response()}.
login(Req) ->
  response_utils:ok(#{message => <<"Logged in!">>}).




get_from_json(Key, Data) ->
  case maps:is_key(Key, Data) of
    true -> maps:get(Key, Data);
    _ -> {error, missing_key}
  end.


do_hash_async(Password, CallbackPid, Ref) ->
    Hash = errm_argon:hash(Password, interactive),
    CallbackPid ! {hash_result, Ref, Hash}.

hash_password_async(Password) ->
    Ref = make_ref(),
    _Pid = spawn(fun() -> do_hash_async(Password, self(), Ref) end),
    receive
        {hash_result, Ref, Hash} -> {ok, Hash}
    after 5000 -> {error, timeout}
    end.
