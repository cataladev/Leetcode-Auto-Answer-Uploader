defmodule LeetCodeSync.Env do
  @moduledoc """
  Minimal `.env` parser for simple `KEY=value` configuration files.
  """

  @spec load_file!(Path.t()) :: :ok
  def load_file!(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(:ok, &load_line/2)
  end

  defp load_line(line, acc) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" -> acc
      String.starts_with?(trimmed, "#") -> acc
      true -> parse_assignment(trimmed)
    end
  end

  defp parse_assignment(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        trimmed_key = String.trim(key)

        if is_nil(System.get_env(trimmed_key)) do
          System.put_env(trimmed_key, normalize_value(String.trim(value)))
        end

        :ok

      _ ->
        raise ArgumentError, "Invalid env line: #{line}"
    end
  end

  defp normalize_value(value) do
    value
    |> strip_quotes()
    |> expand_home()
  end

  defp strip_quotes("\"" <> rest), do: rest |> String.trim_trailing("\"")
  defp strip_quotes("'" <> rest), do: rest |> String.trim_trailing("'")
  defp strip_quotes(value), do: value

  defp expand_home("~/" <> rest), do: Path.join(System.user_home!(), rest)
  defp expand_home(value), do: value
end
