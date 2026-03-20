defmodule LeetCodeSync.LeetCodeClient do
  @moduledoc """
  LeetCode HTTP client for recent accepted submissions, question metadata,
  and authenticated submission detail lookup.
  """

  alias LeetCodeSync.{Config, HTTP, JSON}
  require Logger

  @recent_ac_query """
  query recentAcSubmissions($username: String!, $limit: Int!) {
    recentAcSubmissionList(username: $username, limit: $limit) {
      id
      title
      titleSlug
      timestamp
    }
  }
  """

  @matched_user_query """
  query matchedUser($username: String!) {
    matchedUser(username: $username) {
      username
      profile {
        ranking
      }
    }
  }
  """

  @question_query """
  query questionData($titleSlug: String!) {
    question(titleSlug: $titleSlug) {
      questionFrontendId
      title
      titleSlug
      difficulty
      topicTags {
        name
        slug
      }
    }
  }
  """

  @submission_list_query """
  query submissionList($offset: Int!, $limit: Int!, $questionSlug: String!) {
    submissionList(offset: $offset, limit: $limit, questionSlug: $questionSlug) {
      submissions {
        id
        statusDisplay
        lang
        runtime
        memory
        timestamp
        url
      }
    }
  }
  """

  @spec fetch_recent_accepted_submissions(Config.t()) ::
          {:ok, [map()]} | {:error, term()}
  def fetch_recent_accepted_submissions(config) do
    variables = %{
      "username" => config.leetcode_username,
      "limit" => config.backfill || config.recent_accepted_limit
    }

    with {:ok, payload} <- graphql(config, @recent_ac_query, variables) do
      submissions = get_in(payload, ["data", "recentAcSubmissionList"]) || []

      case submissions do
        [] -> handle_empty_recent_submission_list(config)
        entries -> {:ok, Enum.map(entries, &normalize_recent_submission/1)}
      end
    end
  end

  @spec fetch_question_details(Config.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def fetch_question_details(config, title_slug) do
    with {:ok, payload} <- graphql(config, @question_query, %{"titleSlug" => title_slug}),
         question when is_map(question) <- get_in(payload, ["data", "question"]) do
      {:ok, normalize_question(question)}
    else
      nil -> {:error, {:question_not_found, title_slug}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_latest_submission_code(Config.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def fetch_latest_submission_code(config, title_slug) do
    with :ok <- ensure_auth_ready(config),
         {:ok, payload} <-
           graphql(config, @submission_list_query, %{
             "offset" => 0,
             "limit" => max(config.backfill || 20, 20),
             "questionSlug" => title_slug
           }),
         submissions when is_list(submissions) <- extract_submission_list(payload),
         accepted when accepted != [] <- accepted_submissions(submissions),
         latest <- Enum.max_by(accepted, &Map.fetch!(&1, :timestamp)),
         {:ok, html} <- fetch_submission_page(config, latest.id),
         {:ok, submitted_code} <- extract_submission_code(html) do
      {:ok,
       %{
         submission_id: latest.id,
         language: latest.language,
         runtime: latest.runtime,
         memory: latest.memory,
         timestamp: latest.timestamp,
         submitted_code: submitted_code
       }}
    else
      [] -> {:error, {:accepted_submission_missing, title_slug}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_empty_recent_submission_list(config) do
    with {:ok, payload} <- graphql(config, @matched_user_query, %{"username" => config.leetcode_username}) do
      case get_in(payload, ["data", "matchedUser", "username"]) do
        nil -> {:error, {:invalid_username, config.leetcode_username}}
        _username -> {:ok, []}
      end
    end
  end

  defp graphql(config, query, variables) do
    response =
      config
      |> HTTP.client()
      |> Req.post(url: "/graphql", json: %{query: query, variables: variables})

    case response do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        payload = normalize_payload(body)

        case payload do
          %{"errors" => errors} when is_list(errors) -> {:error, {:graphql_error, errors}}
          value -> {:ok, value}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, normalize_payload(body)}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp fetch_submission_page(config, submission_id) do
    response =
      config
      |> HTTP.client()
      |> Req.get(url: "/submissions/detail/#{submission_id}/", raw: true)

    case response do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, IO.iodata_to_binary(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:submission_page_http_error, status, submission_id}}

      {:error, reason} ->
        {:error, {:submission_page_request_failed, reason, submission_id}}
    end
  end

  defp normalize_payload(body) when is_binary(body), do: JSON.decode!(body)
  defp normalize_payload(body), do: body

  defp normalize_recent_submission(entry) do
    %{
      id: entry["id"],
      title: entry["title"],
      title_slug: entry["titleSlug"],
      timestamp: parse_timestamp(entry["timestamp"]),
      url: "https://leetcode.com/problems/#{entry["titleSlug"]}/"
    }
  end

  defp normalize_question(question) do
    %{
      frontend_id: question["questionFrontendId"],
      title: question["title"],
      title_slug: question["titleSlug"],
      difficulty: question["difficulty"],
      topic_tags: question["topicTags"] || []
    }
  end

  defp extract_submission_list(payload) do
    get_in(payload, ["data", "submissionList", "submissions"]) ||
      get_in(payload, ["data", "submissionList", "submissionsDump"]) ||
      get_in(payload, ["data", "submissionList", "submissions_dump"]) ||
      []
  end

  defp accepted_submissions(submissions) do
    submissions
    |> Enum.map(&normalize_submission/1)
    |> Enum.filter(&(&1.status == "Accepted"))
  end

  defp normalize_submission(entry) do
    %{
      id: entry["id"],
      status: entry["statusDisplay"] || entry["status_display"],
      language: entry["lang"],
      runtime: entry["runtime"],
      memory: entry["memory"],
      timestamp: parse_timestamp(entry["timestamp"]),
      url: entry["url"]
    }
  end

  defp parse_timestamp(value) when is_integer(value), do: value
  defp parse_timestamp(value) when is_binary(value), do: value |> String.to_integer()

  defp ensure_auth_ready(config) do
    cond do
      is_nil(config.leetcode_session) ->
        {:error, :leetcode_auth_not_configured}

      is_binary(config.leetcode_auth_username) and
          config.leetcode_auth_username != config.leetcode_username ->
        {:error,
         {:auth_username_mismatch, config.leetcode_auth_username, config.leetcode_username}}

      true ->
        :ok
    end
  end

  defp extract_submission_code(html) do
    patterns = [
      {:single_quoted, ~r/submissionCode:\s*'((?:\\'|[^'])*)'/s},
      {:double_quoted, ~r/"submissionCode":"((?:\\.|[^"])*)"/s},
      {:double_quoted, ~r/"code":"((?:\\.|[^"])*)"/s}
    ]

    patterns
    |> Enum.find_value(fn {kind, pattern} ->
      case Regex.run(pattern, html, capture: :all_but_first) do
        [encoded] -> {:ok, decode_embedded_code(encoded, kind)}
        _ -> nil
      end
    end)
    |> case do
      nil -> {:error, :submission_code_not_found}
      value -> value
    end
  end

  defp decode_embedded_code(encoded, :single_quoted) do
    encoded
    |> String.replace("\\'", "'")
    |> String.replace("\"", "\\\"")
    |> then(&Jason.decode!("\"" <> &1 <> "\""))
  rescue
    error ->
      Logger.debug("Failed to decode single-quoted submissionCode: #{inspect(error)}")
      encoded
  end

  defp decode_embedded_code(encoded, :double_quoted) do
    Jason.decode!("\"" <> encoded <> "\"")
  rescue
    error ->
      Logger.debug("Failed to decode JSON submissionCode: #{inspect(error)}")
      encoded
  end
end
