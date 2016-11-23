-module(worker_terminal).
-export([
  init/0
]).
-include("../headers/settings.hrl").

init() ->
  case gen_tcp:connect(?SERVER_ADDR, ?WORKER_PORT, ?WORKER_TERMINAL_OPTIONS) of
    {ok, Socket} ->
      connected(Socket);
    {error, Reason} ->
      ?DBGF("Connect error: ~p\n",[Reason]),
      init()
  end,
  ok.

connected(Socket) ->
  Ref = make_ref(),
  case gen_tcp:send(Socket,packet:bin_encode({Ref,are_you_there})) of % kinda handshake ;)
    ok ->
      ?DBG("are_you_there -> ok\n"),
      % case gen_tcp:recv(Socket,0) of
      receive
        {tcp,Socket,Data} ->
          ?DBGF("are_you_there -> ~p\n",[packet:bin_decode(Data)]),
          ok;
        {error, Reason} ->
          ?DBGF("failed to receive response for are_you_there: ~p\n",[Reason]),
          error;
        Other ->
          ?DBGF("got other response for are_you_there: ~p\n",[Other]),
          other
      end;
    {error, Reason} ->
      ?DBGF("failed to send are_you_there: ~p\n",[Reason]),
      error
  end.