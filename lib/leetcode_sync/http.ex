defmodule LeetCodeSync.HTTP do
  @moduledoc """
  Shared Req client construction for LeetCode and GitHub-facing HTTP requests.
  """

  alias LeetCodeSync.Config

  @user_agent "leetcode-sync/0.1.0 (+https://github.com/cataladev/leetcode)"

  @spec client(Config.t()) :: Req.Request.t()
  def client(config) do
    Req.new(
      base_url: "https://leetcode.com",
      headers: base_headers(config),
      receive_timeout: config.request_timeout_ms,
      connect_options: [timeout: config.request_timeout_ms],
      retry: :transient,
      max_retries: 3
    )
  end

  defp base_headers(config) do
    [
      {"user-agent", @user_agent},
      {"referer", "https://leetcode.com/"},
      {"accept", "application/json, text/plain, */*"}
    ]
    |> maybe_add_csrf(config.leetcode_csrf_token)
    |> maybe_add_cookie(cookie_header(config))
  end

  defp cookie_header(config) do
    []
    |> maybe_append_cookie("LEETCODE_SESSION", config.leetcode_session)
    |> maybe_append_cookie("csrftoken", config.leetcode_csrf_token)
    |> Enum.join("; ")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp maybe_append_cookie(cookies, _key, nil), do: cookies
  defp maybe_append_cookie(cookies, _key, ""), do: cookies
  defp maybe_append_cookie(cookies, key, value), do: cookies ++ ["#{key}=#{value}"]

  defp maybe_add_csrf(headers, nil), do: headers
  defp maybe_add_csrf(headers, ""), do: headers
  defp maybe_add_csrf(headers, token), do: [{"x-csrftoken", token} | headers]

  defp maybe_add_cookie(headers, nil), do: headers
  defp maybe_add_cookie(headers, value), do: [{"cookie", value} | headers]
end
