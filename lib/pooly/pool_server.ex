defmodule Pooly.PoolServer do
  @moduledoc false
  use GenServer
  import Supervisor.Spec

  # API

  defmodule State do
    @moduledoc """
    defines a struct to hold the server state
    """
    defstruct pool_sup: nil,
              worker_sup: nil,
              monitors: nil,
              size: nil,
              workers: nil,
              name: nil,
              mfa: nil
  end

  def start_link(pool_sup, pool_config) do
    GenServer.start_link(__MODULE__,
                         [pool_sup, pool_config],
                         name: name(pool_config[:name]))
  end

  def checkout(pool_name) do
    GenServer.call(name(pool_name), :checkout)
  end

  def checkin(pool_name, worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  def get_state(pool_name) do
    GenServer.call(name(pool_name), :get_state)
  end

  # CALLBACK FUNCTIONS

  def init([pool_sup, pool_config]) when is_pid(pool_sup) do
    # Trap exits from workers
    Process.flag(:trap_exit, true)
    # create the ets table to store checked out workers
    monitors = :ets.new(:monitors, [:private])

    # go throught the init functions to build the pool state
    init(pool_config, %State{pool_sup: pool_sup, monitors: monitors})
  end

  def init([{:name, name} | rest], state) do
    init(rest, %{state | name: name})
  end

  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([{:size, size} | rest], state) do
    init(rest, %{state | size: size})
  end

  def init([], state) do
    # Send message to self to start the supervisor when state is set
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  # Ignore everything else and keep going
  def init([_ | rest], state) do
    init(rest, state)
  end

  def handle_call(:checkout, {from_pid, _ref}, state = %{workers: workers,
                                                         monitors: monitors}) do
    case workers do
      [worker | rest] ->
        # monitor the process checking out the worker
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}
      [] ->
        {:reply, :noproc, state}
    end
  end

  def handle_call(:status, _from, state = %{workers: workers,
                                            monitors: monitors}) do

    {:reply, {length(workers)}, :ets.info(monitors, :size), state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:checkin, worker}, state = %{workers: workers,
                                                monitors: monitors}) do

    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, %{state | workers: [pid | workers]}}
      [] ->
        {:noreply, state}
    end
  end

  def handle_info(:start_worker_supervisor, state = %{pool_sup: pool_sup,
                                                      name: name,
                                                      mfa: mfa,
                                                      size: size}) do
    # Tell the pool supervisor to start a worker supervisor as a child process
    {:ok, worker_sup} =
      Supervisor.start_child(pool_sup, supervisor_spec(name, mfa))

    # Start workers through the worker superisor
    workers = prepopulate(size, worker_sup)
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  # Handle down event from the client process
  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors,
                                                   workers: workers}) do

    case :ets.match(monitors, {:"$1", ref}) do
      [{pid}] ->
        true = :ets.delete(monitors, pid)
        # check the worker back in
        new_state = %{state | workers: [pid | workers]}
        {:noreply, new_state}
      [[]] ->
        {:noreply, state}
    end
  end

  # Handle exits from worker processes
  def handle_info({:EXIT, pid, _reason}, state = %{monitors: monitors,
                                                   workers: workers,
                                                   pool_sup: pool_sup}) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        # demonitor the client processes
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        # start up another worker
        new_state = %{state | workers: [new_worker(pool_sup) | workers]}
        {:noreply, new_state}
      _ ->
        {:noreply, state}
    end
  end

  # TODO: fix that this function never gets called
  # handle exits from worker supervisor
  def handle_info({:EXIT, worker_sup, reason},
    state = %{worker_sup: worker_sup}) do
    # stop the server
    {:stop, reason, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  # PRIVATE FUNCTIONS

  defp name(pool_name) do
    :"#{pool_name}Server"
  end

  defp supervisor_spec(name, mfa) do
    options = [id: name <> "WorkerSupervisor", restart: :temporary]
    # returns a child spec for the worker supervisor
    supervisor(Pooly.WorkerSupervisor, [self(), mfa], options)
  end

  # Fill up a list of n(size) workers
  defp prepopulate(size, supervisor) do
    prepopulate(size, supervisor, [])
  end

  defp prepopulate(size, _supervisor, workers) when size < 1 do
    workers
  end

  defp prepopulate(size, supervisor, workers) do
    prepopulate(size - 1, supervisor, [new_worker(supervisor) | workers])
  end

  defp new_worker(supervisor) do
    {:ok, worker} = Supervisor.start_child(supervisor, [[]])
    worker
  end
end
