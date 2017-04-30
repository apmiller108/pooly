defmodule Pooly.Server do
  @moduledoc false
  use GenServer
  import Supervisor.Spec

  # API FUNCTIONS

  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  # Checkout a worker from the pool
  def checkout(pool_name) do
    GenServer.call(:"#{pool_name}Server", :checkout)
  end

  # Check a worker back into the pool
  def checkin(pool_name, worker_pid) do
    GenServer.cast(:"#{pool_name}Server", {:checkin, worker_pid})
  end

  # Check the pool status
  def status(pool_name) do
    GenServer.call(:"#{pool_name}Server", :status)
  end

  # Get the current state
  def get_state(pool_name) do
    GenServer.call(:"#{pool_name}Server", :get_state)
  end

  # CALLBACK FUNCTIONS

  # Invoked when start_link/3 is called above. Goes through all the
  # pools_config and sends the :start_pool message with each config.
  def init(pools_config) do
    pools_config
    |> Enum.each(fn(pool_config) -> send_start_pool(pool_config)end)

    {:ok, pools_config}
  end

  def handle_info({:start_pool, pool_config}, state) do
    {:ok, _pool_supervisor} =
      Supervisor.start_child(
        Pooly.PoolsSupervisor,
        supervisor_spec(pool_config)
      )

    {:noreply, state}
  end

  # PRIVATE FUNCTIONS

  # Send the :start_pool message to itself
  defp send_start_pool(pool_config) do
    send(self(), {:start_pool, pool_config})
  end

  defp supervisor_spec(pool_config) do
    # By using the :id option we can create unique superisor specs so
    # we avoid the 'already started' error
    opts = [id: :"#{pool_config[:name]}Supervisor"]
    supervisor(Pooly.PoolSupervisor, [pool_config], opts)
  end
end
