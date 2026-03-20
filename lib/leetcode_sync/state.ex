defmodule LeetCodeSync.State do
  @moduledoc """
  Persistent local state for idempotent sync runs.
  """

  alias LeetCodeSync.{FileUtils, JSON}

  @default_state %{
    "version" => 1,
    "last_run_at" => nil,
    "processed_problems" => %{}
  }

  @spec load(Path.t()) :: {:ok, map()} | {:error, term()}
  def load(path) do
    cond do
      File.exists?(path) ->
        path
        |> File.read()
        |> case do
          {:ok, contents} -> {:ok, normalize_state(JSON.decode!(contents))}
          {:error, reason} -> {:error, {:state_read_failed, path, reason}}
        end

      true ->
        {:ok, @default_state}
    end
  rescue
    error ->
      {:error, {:state_decode_failed, path, Exception.message(error)}}
  end

  @spec save!(Path.t(), map()) :: :ok
  def save!(path, state) do
    FileUtils.ensure_directory!(path)
    File.write!(path, JSON.encode_pretty!(state) <> "\n")
  end

  @spec processed?(map(), String.t()) :: boolean()
  def processed?(state, title_slug) do
    get_in(state, ["processed_problems", title_slug]) != nil
  end

  @spec mark_processed(map(), map(), map()) :: map()
  def mark_processed(state, problem, attrs) do
    processed =
      Map.put(state["processed_problems"], problem.title_slug, %{
        "title" => problem.title,
        "title_slug" => problem.title_slug,
        "folder_name" => attrs.folder_name,
        "commit_message" => attrs.commit_message,
        "commit_hash" => attrs.commit_hash,
        "push_status" => attrs.push_status,
        "submitted_code_retrieved" => attrs.submitted_code_retrieved,
        "synced_at" => now()
      })

    state
    |> Map.put("processed_problems", processed)
    |> Map.put("last_run_at", now())
  end

  @spec mark_run_complete(map()) :: map()
  def mark_run_complete(state), do: Map.put(state, "last_run_at", now())

  defp normalize_state(state) do
    @default_state
    |> Map.merge(state)
    |> Map.update!("processed_problems", fn problems -> problems || %{} end)
  end

  defp now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
