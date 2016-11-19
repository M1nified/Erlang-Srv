-module(display_connector).
-export([
  spawn/1
]).
-include("../headers/settings.hrl").

-spec spawn(thread()) -> thread().
spawn(ReStThread) ->
  MyRef = make_ref(),
  Pid = erlang:spawn(fun() -> run(ReStThread) end),
  Me = #thread{
    pid = Pid, ref=MyRef
  },
  {ok, Me}.

-spec run(thread()) -> any().
run(ReStThread) ->
  Settings = #display_connector_settings{
    readystorage = ReStThread
  },
  listen_go(Settings).

-spec listen_go(display_connector_settings()) -> any().
listen_go(Settings) ->
  case gen_tcp:listen(
      ?DISPLAY_PORT,
      [
        binary,
        {packet, 0},
        {active, false},
        {keepalive, true}
      ]
    ) of
    {ok, ListenSocket} -> accept_go(ListenSocket,Settings);
    {error, Reason} -> on_error({error, listen_go, Reason})
  end.

-spec accept_go(socket(),display_connector_settings()) -> any().
accept_go(ListenSocket,Settings) ->
  case gen_tcp:accept(ListenSocket) of
    {ok, Socket} -> accept_ok(Socket, Settings);
    {error, Reason} -> on_error({error, listen_ok, Reason})
  end.

-spec accept_ok(socket(),display_connector_settings()) -> any().
accept_ok(Socket,Settings) ->
  listen(Socket,Settings),
  gen_tcp:close(Socket).

-spec listen(socket(),display_connector_settings()) -> any().
listen(Socket,Settings) ->
  case gen_tcp:recv(Socket,0) of
    {ok, Data} ->
      process_request(Settings,Data),
      listen(Socket,Settings);
    {error, Reason} ->
      on_error({error, listen, Reason})
  end.

-spec process_request(display_connector_settings(),any()) -> any().
process_request(Settings,Data) ->
  ok.

%%
on_error({_,Where,Why}) ->
  {error,Where,Why}.
