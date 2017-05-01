defmodule Pooly.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(pools_config) do
    Supervisor.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def init(pools_config) do
    # Top level supervisor supervises the PoolsSupervisor and Pooly.Server
    # NOTE: start_link/3 in invoked on the child modules by default
    children = [
      supervisor(Pooly.PoolsSupervisor, []),
      worker(Pooly.Server, [pools_config])
    ]

    # use :one_for_all so if Pooly.Server crashes it will take
    # down the WorkerSupervisor which gets restarted with Pooly.Server
    options = [strategy: :one_for_all]

    supervise(children, options)
  end
end
