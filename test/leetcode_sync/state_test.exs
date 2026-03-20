defmodule LeetCodeSync.StateTest do
  use ExUnit.Case, async: false

  alias LeetCodeSync.State

  setup do
    state_path =
      System.tmp_dir!()
      |> Path.join("leetcode-sync-state-#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(state_path) end)
    {:ok, state_path: state_path}
  end

  test "loads default state when file is missing", %{state_path: state_path} do
    assert {:ok, %{"processed_problems" => %{}}} = State.load(state_path)
  end

  test "saves and reloads processed problems", %{state_path: state_path} do
    {:ok, state} = State.load(state_path)

    updated_state =
      State.mark_processed(
        state,
        %{title: "Two Sum", title_slug: "two-sum"},
        %{
          folder_name: "Two Sum",
          commit_message: "Add LeetCode solution: Two Sum",
          commit_hash: "abc123",
          push_status: "pushed",
          submitted_code_retrieved: true
        }
      )

    :ok = State.save!(state_path, updated_state)

    assert {:ok, reloaded_state} = State.load(state_path)
    assert State.processed?(reloaded_state, "two-sum")
    assert get_in(reloaded_state, ["processed_problems", "two-sum", "commit_hash"]) == "abc123"
  end
end
