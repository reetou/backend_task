defmodule CarRental do
  @moduledoc """
  Documentation for `CarRental`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> CarRental.hello()
      :world

  """

  alias CarRental.Clients
  alias CarRental.Clients.Processor

  def hello do
    :world
  end

  @doc """
  Function for demonstration purposes to run the processing without waiting for the cron job.
  """
  @spec process_clients() :: :ok
  def process_clients do
    Clients.list_clients()
    |> then(fn {:ok, clients} ->
      {:ok, other_batch} = Clients.list_clients()
      :ok = Processor.push(clients ++ other_batch)
    end)
    |> then(fn _ ->
      :timer.sleep(15000)

      process_clients()
    end)

    :ok
  end
end
