defmodule Pooly.WorkerSupervisor do
  @moduledoc false
  use Supervisor

  # API FUNCTIONS

  # Requires a three element tuple which is bound to variable mfa
  # (module, function, arguments)
  def start_link(pool_server, {_, _, _} = mfa) do
    Supervisor.start_link(__MODULE__, [pool_server, mfa])
  end

  # CALLBACK FUNCTIONS

  def init([pool_server, {module, function, args}]) do
    # The supervisor will take down the pool server on crash
    Process.link(pool_server)
    # The worker should always be restarted with the function from the tuple
    worker_options = [restart: :temporary,
                      shutdown: 5000,
                      function: function]

    # Supervisor.Spec.worker/3 creates the child spec
    children = [worker(module, args, worker_options)]

    supervision_options = [
      strategy: :simple_one_for_one, # Restart strategy
      max_restarts: 5, # max restarts in a timeframe
      max_seconds: 5 # the restart timeframe (defaults to 5 sec)
    ]

    # Supervisor.Spec.supervise/2 takes a list and options.
    supervise(children, supervision_options)
  end
end
