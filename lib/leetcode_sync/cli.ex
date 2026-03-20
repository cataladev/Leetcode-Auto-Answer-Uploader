defmodule LeetCodeSync.CLI do
  @moduledoc """
  Command line entrypoint for the LeetCode sync tool.
  """

  alias LeetCodeSync.{Config, Sync}
  require Logger

  @spec main([String.t()]) :: no_return()
  def main(argv \\ System.argv()) do
    {options, _, invalid} =
      OptionParser.parse(argv,
        strict: [
          dry_run: :boolean,
          verbose: :boolean,
          once: :boolean,
          healthcheck: :boolean,
          backfill: :integer,
          env_file: :string,
          project_root: :string
        ]
      )

    if invalid != [] do
      invalid
      |> Enum.map_join(", ", fn {key, value} -> "--#{key}=#{value}" end)
      |> fail!("Unsupported arguments")
    end

    config = Config.load!(options)
    configure_logger(config)

    case options[:healthcheck] do
      true ->
        config
        |> Sync.healthcheck()
        |> exit_with_status()

      false ->
        config
        |> Sync.run()
        |> exit_with_status()
    end
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      System.halt(1)
  end

  defp configure_logger(config) do
    level = if config.verbose, do: :debug, else: :info
    Logger.configure(level: level)
  end

  defp exit_with_status({:ok, summary}) do
    Logger.info("Run complete: #{inspect(summary)}")
    System.halt(0)
  end

  defp exit_with_status({:error, reason}) do
    Logger.error("Run failed: #{inspect(reason)}")
    System.halt(1)
  end

  defp fail!(message, details) do
    raise ArgumentError, "#{message}: #{details}"
  end
end
