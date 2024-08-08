defmodule CarRental.Clients.Processor do
  @moduledoc """
  This module is responsible for processing clients in bulk to avoid hitting into rate limit.

  It processes clients in bulk and calculates trust score for each client and saves it.
  """

  alias CarRental.TrustScore
  alias CarRental.Clients

  use GenServer

  require Logger

  @interval 7_000
  @bulk_size 100

  @impl true
  def init(_) do
    schedule_process()

    {:ok,
     %{
       clients: [],
       count: 0
     }}
  end

  @spec start_link(any()) :: {:ok, pid()} | {:error, any()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec push(clients :: list(map())) :: :ok
  def push(clients) do
    Logger.debug("Scheduling #{length(clients)} clients to process")

    :ok = GenServer.cast(__MODULE__, {:push, clients})
  end

  @impl true
  def handle_cast({:push, clients}, state) do
    Logger.debug("Received #{length(clients)} clients to process")

    state
    |> Map.put(:clients, state.clients ++ clients)
    |> Map.update!(:count, &(&1 + length(clients)))
    |> then(fn x -> {:noreply, x} end)
  end

  @impl true
  def handle_info(:process, state = %{count: count}) when count > 0 do
    state
    |> Map.fetch!(:clients)
    |> Enum.split(@bulk_size)
    |> then(fn {to_process, rest} ->
      Logger.debug("Processing #{length(to_process)} clients")

      :ok = calculate_and_save_score(to_process)

      Logger.debug("Processed #{length(to_process)}/#{count} clients")

      rest
    end)
    |> then(fn rest ->
      schedule_process(@interval)

      {:noreply, Map.merge(state, %{clients: rest, count: length(rest)})}
    end)
  end

  def handle_info(:process, state = %{count: 0}) do
    Logger.debug("No clients to process")

    schedule_process(@interval)

    {:noreply, state}
  end

  defp calculate_and_save_score(clients) do
    clients
    |> TrustScore.build_params()
    |> TrustScore.calculate_score()
    |> Clients.build_params()
    |> Enum.map(fn x ->
      {:ok, :saved} = Clients.save_score_for_client(x)
    end)

    :ok
  end

  defp schedule_process(delay \\ 0) do
    Logger.debug("Next bulk will be ran in #{delay} ms")

    Process.send_after(self(), :process, delay)
  end
end
