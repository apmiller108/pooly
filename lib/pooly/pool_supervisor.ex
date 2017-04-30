defmodule Pooly.PoolSupervisor do
  @moduledoc false
  use Supervisor

  def start_link(pool_config) do
    Supervisor.start_link(
      __MODULE__,
      pool_config,
      name: :"#{pool_config[:name]}Supervisor"
    )
  end

  def init(pool_config) do
    # If a worker crashes, restart all workers, worker supervisor
    # and pool server
    options = [strategy: :one_for_all]

    children = [worker(Pooly.PoolServer, [self(), pool_config])]

    # supervise the PoolServer
    supervise(children, options)
  end
end
