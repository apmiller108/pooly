defmodule SampleWorker do
  use GenServer

  # API FUNCTIONS

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  # CALLBACK FUNCTIONS

  def init(:ok) do
    state = %{}
    {:ok, state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end
end
