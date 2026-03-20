defmodule LeetCodeSync.FileLock do
  @moduledoc """
  Simple exclusive file lock to prevent concurrent sync runs.
  """

  alias LeetCodeSync.FileUtils

  @spec with_lock(Path.t(), (() -> {:ok, map()} | {:error, term()})) ::
          {:ok, map()} | {:error, term()}
  def with_lock(lock_path, fun) when is_function(fun, 0) do
    FileUtils.ensure_directory!(lock_path)

    case File.open(lock_path, [:write, :exclusive]) do
      {:ok, handle} ->
        IO.binwrite(handle, "#{System.pid()} #{DateTime.utc_now() |> DateTime.to_iso8601()}\n")

        try do
          fun.()
        after
          File.close(handle)
          File.rm(lock_path)
        end

      {:error, :eexist} ->
        {:error, :lock_already_held}

      {:error, reason} ->
        {:error, {:lock_unavailable, reason}}
    end
  end
end
