defmodule LeetCodeSync.FileUtilsTest do
  use ExUnit.Case, async: true

  alias LeetCodeSync.FileUtils

  test "sanitizes invalid filesystem characters" do
    assert FileUtils.safe_folder_name("Two Sum: Easy/?") == "Two Sum Easy"
  end

  test "protects Windows reserved names" do
    assert FileUtils.safe_folder_name("CON") == "_CON"
  end

  test "uses language mapping when extension is auto" do
    assert FileUtils.solution_extension("Python3", "auto") == "py"
    assert FileUtils.solution_extension("Rust", "auto") == "rs"
  end

  test "uses explicit extension override" do
    assert FileUtils.solution_extension("Python3", ".txt") == "txt"
  end
end
