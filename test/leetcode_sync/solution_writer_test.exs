defmodule LeetCodeSync.SolutionWriterTest do
  use ExUnit.Case, async: true

  alias LeetCodeSync.SolutionWriter

  setup do
    repo_path =
      System.tmp_dir!()
      |> Path.join("leetcode-sync-solution-writer-#{System.unique_integer([:positive])}")

    File.rm_rf!(repo_path)
    File.mkdir_p!(repo_path)

    on_exit(fn ->
      File.rm_rf!(repo_path)
    end)

    %{repo_path: repo_path}
  end

  test "detects existing legacy numeric solution files", %{repo_path: repo_path} do
    File.mkdir_p!(Path.join(repo_path, "easy"))
    File.write!(Path.join(repo_path, "easy/1351.py"), "# existing solution\n")

    question = %{
      title: "Count Negative Numbers in a Sorted Matrix",
      title_slug: "count-negative-numbers-in-a-sorted-matrix",
      frontend_id: "1351",
      difficulty: "Easy"
    }

    assert SolutionWriter.problem_present?(repo_path, question)
  end

  test "does not report unrelated numeric files as the same problem", %{repo_path: repo_path} do
    File.mkdir_p!(Path.join(repo_path, "easy"))
    File.write!(Path.join(repo_path, "easy/226.py"), "# different solution\n")

    question = %{
      title: "Count Negative Numbers in a Sorted Matrix",
      title_slug: "count-negative-numbers-in-a-sorted-matrix",
      frontend_id: "1351",
      difficulty: "Easy"
    }

    refute SolutionWriter.problem_present?(repo_path, question)
  end

  test "detects an existing title-based folder", %{repo_path: repo_path} do
    File.mkdir_p!(Path.join(repo_path, "Two Sum"))

    question = %{
      title: "Two Sum",
      title_slug: "two-sum",
      frontend_id: "1",
      difficulty: "Easy"
    }

    assert SolutionWriter.problem_present?(repo_path, question)
  end
end
