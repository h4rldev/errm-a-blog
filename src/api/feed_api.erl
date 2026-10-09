-module (feed_api).
-export ([feed/1]).

-spec feed(errm_http:request()) -> {ok, errm_http:response()}.
feed(_Req) ->
  case blog_db:db() of
    {error, Reason} ->
      logger:error("Database open failed: ~p", [Reason]),
      response_utils:error(500, "Database error");
    {ok, Db} ->
      Sql = "SELECT posts.*, users.username FROM posts JOIN users ON posts.author_id = users.uuid ORDER BY posts.posted_at DESC",
      case errm_sqlite:query(Db, Sql) of
        {ok, Rows} ->
          Site = blog_config:get(server_url),
          Body = iolist_to_binary(render(Rows, Site)),
          {ok, {200, #{<<"content-type">> => <<"application/rss+xml; charset=utf-8">>}, Body}};
        {error, Reason1} ->
          logger:error("Error fetching feed posts: ~p", [Reason1]),
          response_utils:error(500, "Database erorr")
      end
  end.

render(Rows, Site) ->
  [<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n">>,
   <<"<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">\n">>,
   <<"<channel>\n">>,
   xml_tag("title", blog_config:get(feed_title)),
   xml_tag("link", Site ++ "/blog"),
   xml_tag("description", blog_config:get(feed_description)),
   [<<"<atom:link href=\"">>, Site, <<"/blog/feed.xml\" rel=\"self\" type=\"application/rss+xml\"/>\n">>],
   [item(Row, Site) || Row <- Rows],
   <<"</channel>\n</rss>\n">>].

item(Row, Site) ->
  Path = case to_binary(maps:get("slug", Row, <<>>)) of
    <<>> -> post_id(Row);
    Slug -> Slug
  end,
  Link = Site ++ "/blog/post/" ++ binary_to_list(Path),
  [<<"<item>\n">>,
   xml_tag("title", maps:get("title", Row, <<>>)),
   xml_tag("link", Link),
   [<<"<guid isPermaLink=\"true\">">>, esc(Link), <<"</guid>\n">>],
   [<<"<pubDate>">>, pub_date(maps:get("posted_at", Row, undefined)), <<"</pubDate>\n">>],
   xml_tag("description", summary(Row)),
   xml_tag("content:encoded", content(Row)),
   [<<"<author>">>, esc(maps:get("username", Row, <<>>)), <<"</author>\n">>],
   [xml_tag("category", Tag) || Tag <- tags(Row)],
   <<"</item>\n">>].

summary(Row) ->
  to_binary(maps:get("summary", Row, <<>>)).

content(Row) ->
  case to_binary(maps:get("content_markdown", Row, <<>>)) of
    <<>> -> summary(Row);
    Markdown -> markdown_to_html(Markdown)
  end.

markdown_to_html(Markdown) ->
  case errm_cmark_gfm_nif:to_html(Markdown) of
    {ok, Html} -> Html;
    {error, _} -> Markdown
  end.

tags(Row) ->
  case errm_json:decode(to_binary(maps:get("tags", Row, <<"[]">>))) of
    {ok, List} when is_list(List) -> [Tag || Tag <- List, is_binary(Tag)];
    _ -> []
  end.

pub_date(Secs) when is_integer(Secs) ->
  {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:system_time_to_universal_time(Secs, second),
  Weekday = lists:nth(calendar:day_of_the_week(Year, Month, Day),
    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
  MonthName = lists:nth(Month,
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]),
  io_lib:format("~s, ~2..0B ~s ~4..0B ~2..0B:~2..0B:~2..0B +0000",
    [Weekday, Day, MonthName, Year, Hour, Minute, Second]);
pub_date(_) ->
  [].

xml_tag(Name, Value) ->
  [<<"<">>, Name, <<">">>, esc(Value), <<"</">>, Name, <<">\n">>].

esc(Value) ->
  iolist_to_binary(escape(to_binary(Value))).

to_binary(Value) ->
  case blog_format:value_to_binary(Value) of
    Binary when is_binary(Binary) -> Binary;
    List when is_list(List) -> iolist_to_binary(List)
  end.

post_id(Row) ->
  case maps:get("id", Row, undefined) of
    Id when is_integer(Id) -> integer_to_binary(Id);
    Id -> to_binary(Id)
  end.

escape(<<>>) ->
  [];
escape(<<Char, Rest/binary>>) ->
  Escaped = case Char of
    $& -> <<"&amp;">>;
    $< -> <<"&lt;">>;
    $> -> <<"&gt;">>;
    $" -> <<"&quot;">>;
    $' -> <<"&apos;">>;
    _ -> <<Char>>
  end,
  [Escaped | escape(Rest)].
