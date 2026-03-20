defmodule LeetCodeSync.FileUtils do
  @moduledoc """
  Filesystem helpers for safe folder names, paths, and extension resolution.
  """

  @windows_reserved_names MapSet.new([
                            "CON",
                            "PRN",
                            "AUX",
                            "NUL",
                            "COM1",
                            "COM2",
                            "COM3",
                            "COM4",
                            "COM5",
                            "COM6",
                            "COM7",
                            "COM8",
                            "COM9",
                            "LPT1",
                            "LPT2",
                            "LPT3",
                            "LPT4",
                            "LPT5",
                            "LPT6",
                            "LPT7",
                            "LPT8",
                            "LPT9"
                          ])

  @language_extension_map %{
    "bash" => "sh",
    "c" => "c",
    "c#" => "cs",
    "c++" => "cpp",
    "dart" => "dart",
    "elixir" => "exs",
    "erlang" => "erl",
    "go" => "go",
    "java" => "java",
    "javascript" => "js",
    "kotlin" => "kt",
    "mysql" => "sql",
    "oracle" => "sql",
    "php" => "php",
    "python" => "py",
    "python3" => "py",
    "ruby" => "rb",
    "rust" => "rs",
    "scala" => "scala",
    "swift" => "swift",
    "typescript" => "ts"
  }

  @spec ensure_directory!(Path.t()) :: :ok
  def ensure_directory!(path) do
    path |> Path.dirname() |> File.mkdir_p!()
  end

  @spec safe_folder_name(String.t()) :: String.t()
  def safe_folder_name(title) do
    title
    |> String.trim()
    |> String.replace(~r/[<>:"\/\\|?*\x00-\x1F]/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.trim_trailing(".")
    |> handle_empty()
    |> handle_reserved_name()
  end

  @spec solution_extension(String.t() | nil, String.t()) :: String.t()
  def solution_extension(language, configured_extension) do
    extension =
      case String.downcase(configured_extension) do
        "auto" -> Map.get(@language_extension_map, normalize_language(language), "txt")
        value -> String.trim_leading(value, ".")
      end

    if extension == "", do: "txt", else: extension
  end

  defp normalize_language(nil), do: nil
  defp normalize_language(language), do: language |> String.trim() |> String.downcase()

  defp handle_empty(""), do: "untitled-problem"
  defp handle_empty(value), do: value

  defp handle_reserved_name(name) do
    upper_name = String.upcase(name)

    if MapSet.member?(@windows_reserved_names, upper_name) do
      "_#{name}"
    else
      name
    end
  end
end
