-module(worker).
-export([
  spawn/2
]).
-define(DEBUG,false).
-include("../headers/server_header.hrl").

-spec spawn(socket(),jm_state()) -> thread() | error.
spawn(Socket,JobsManagerSettings) ->
  % WorkerBoss = #thread{pid = self(),ref = make_ref()},
  InboxThread = worker_inbox:spawn(),
  OutboxThread = worker_outbox:spawn(),
  TheWorkerRef = make_ref(),
  TheWorkerPid = spawn(fun() -> run(TheWorkerRef,JobsManagerSettings,InboxThread,OutboxThread, Socket) end),
  Ref = make_ref(),
  TheWorkerPid ! {self(),Ref,getworker},
  receive
    {Ref,{worker,Worker}} ->
      Worker;
    _ ->
      error
  end.

-spec run(reference(),jm_state(),thread(),thread(),socket()) -> any().
run(TheWorkerRef,JobsManagerSettings,InboxThread,OutboxThread, Socket) ->
  Worker = #worker{
    head = #thread{pid = self(), ref = TheWorkerRef},
    inbox = InboxThread,
    outbox = OutboxThread,
    socket = Socket,
    jmgr = JobsManagerSettings#jm_state.jobsmanager,
    bm = JobsManagerSettings#jm_state.bm
  },
  JobsManagerSettings#jm_state.jobsmanager#thread.pid ! {self(),TheWorkerRef,register_worker,Worker},
  ?DBGF("~p Worker spawned and running...\n~p\n", [TheWorkerRef,Worker]),
  Worker#worker.inbox#thread.pid ! {worker, Worker},
  Worker#worker.outbox#thread.pid ! {worker, Worker},
  % gen_server:start_link({local,Worker#worker.bm},Worker#worker.bm,[{worker,Worker}],[{debug,[log]}]),
  worker_loop(Worker),
  ok.

-spec worker_loop(worker()) -> any().
worker_loop(Worker) ->
  InboxRef = Worker#worker.inbox#thread.ref,
  receive
    {jms, assignment, {MethodType, {task, Task}}} ->
      ?DBGF("~p Received task: ~p\n",[Worker#worker.head#thread.ref, Task]),
      Worker#worker.outbox#thread.pid ! {Worker#worker.head#thread.ref, make_ref(), send, {MethodType, {task, Task}}},
      worker_loop(Worker);
    {inbox,InboxRef, {result, Result}} ->
      Worker#worker.jmgr#thread.pid ! {{worker, Worker},{result, Result}},
      worker_loop(Worker#worker{is_working = false});
    {inbox,InboxRef, {error,enotsock}} -> % kill, terminal disconnected
      kill(Worker);
    {inbox,InboxRef, {error, Reason}} ->
      ?DBGF("~p Received error from inbox: ~p\n",[Worker#worker.head#thread.ref, Reason]),
      worker_loop(Worker);
    % {inbox,InboxRef, Data} ->
    %   ?DBGF("~p Received from worker's inbox: ~p\n",[Worker#worker.head#thread.ref,Data]),
    %   gen_server:cast(Worker#worker.bm,{inbox,Worker,Data}),
    %   worker_loop(Worker);
    {Sender, MsgRef, getworker} ->
      Sender ! {MsgRef,{worker,Worker}},
      worker_loop(Worker)
  end.

-spec kill(worker()) -> ok | error.
kill(Worker) ->
  kill(Worker,no_reason),
  ok.
kill(Worker, Reason) ->
  Worker#worker.inbox#thread.pid ! die,
  Worker#worker.outbox#thread.pid ! die,
  Worker#worker.jmgr#thread.pid ! {worker_shutdown, {worker, Worker}, {reason, Reason}},
  ok.