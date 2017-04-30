defmodule Pooly.PoolsSupervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # If one pool supervisor crashes, it will not affect the others
    opts = [strategy: :one_for_one]

    supervise([], opts)
  end
end
