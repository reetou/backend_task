defmodule CarRental.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Crontab.CronExpression

  @impl true
  def start(_type, _args) do
    children = [
      {CarRental.TrustScore.RateLimiter, []},
      {CarRental.Scheduler, []},
      {CarRental.Clients.Processor, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CarRental.Supervisor]

    case Supervisor.start_link(children, opts) do
      start_result = {:ok, _pid} ->
        init_cron()
        start_result

      start_result ->
        start_result
    end
  end

  def init_cron do
    CarRental.Scheduler.new_job()
    |> Quantum.Job.set_name(:calculate_score)
    |> Quantum.Job.set_schedule(~e[0 0 * * 7])
    |> Quantum.Job.set_task(fn -> :ok end)
    |> CarRental.Scheduler.add_job()
  end
end
