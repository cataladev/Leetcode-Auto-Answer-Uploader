defmodule LeetCodeSync do
  @moduledoc """
  Public entrypoint for running LeetCode repository syncs.
  """

  alias LeetCodeSync.{Config, Sync}

  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(opts \\ []) do
    opts
    |> Config.load!()
    |> Sync.run()
  end
end
