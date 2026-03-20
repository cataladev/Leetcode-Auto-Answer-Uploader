defmodule LeetCodeSync.Config do
  @moduledoc """
  Runtime configuration loaded from environment variables and CLI overrides.
  """

  alias LeetCodeSync.Env

  @enforce_keys [
    :project_root,
    :leetcode_username,
    :target_repo_url,
    :target_repo_local_path,
    :solution_file_extension,
    :git_branch,
    :commit_author_name,
    :commit_author_email,
    :state_file_path,
    :lock_file_path,
    :request_timeout_ms,
    :recent_accepted_limit,
    :sync_interval_minutes,
    :tmp_dir
  ]
  defstruct [
    :project_root,
    :leetcode_username,
    :target_repo_url,
    :target_repo_local_path,
    :solution_file_extension,
    :git_branch,
    :commit_author_name,
    :commit_author_email,
    :leetcode_session,
    :leetcode_csrf_token,
    :leetcode_auth_username,
    :github_token,
    :state_file_path,
    :lock_file_path,
    :request_timeout_ms,
    :recent_accepted_limit,
    :sync_interval_minutes,
    :tmp_dir,
    dry_run: false,
    verbose: false,
    push_after_each_commit: true,
    auto_clone_target_repo: true,
    allow_dirty_target_repo: false,
    stop_on_push_failure: true,
    backfill: nil
  ]

  @type t :: %__MODULE__{}

  @spec load!(keyword()) :: t()
  def load!(cli_options \\ []) do
    project_root =
      cli_options[:project_root]
      |> default(File.cwd!())
      |> Path.expand()

    env_file =
      cli_options[:env_file]
      |> default(Path.join(project_root, ".env"))
      |> Path.expand()

    if File.exists?(env_file) do
      Env.load_file!(env_file)
    end

    target_repo_local_path =
      "TARGET_REPO_LOCAL_PATH"
      |> string_env("~/Development/leetcode")
      |> Path.expand()

    state_file_path =
      "STATE_FILE_PATH"
      |> string_env(".data/state.json")
      |> normalize_runtime_path(project_root)

    lock_file_path =
      "LOCK_FILE_PATH"
      |> string_env(".data/leetcode-sync.lock")
      |> normalize_runtime_path(project_root)

    %__MODULE__{
      project_root: project_root,
      leetcode_username: string_env("LEETCODE_USERNAME", "cataladev"),
      target_repo_url: string_env("TARGET_REPO_URL", "https://github.com/cataladev/leetcode"),
      target_repo_local_path: target_repo_local_path,
      solution_file_extension: string_env("SOLUTION_FILE_EXTENSION", "auto"),
      git_branch: string_env("GIT_BRANCH", "main"),
      commit_author_name: string_env("COMMIT_AUTHOR_NAME", "Carlos Arena"),
      commit_author_email: string_env("COMMIT_AUTHOR_EMAIL", "carlos@catala.dev"),
      leetcode_session: nullable_env("LEETCODE_SESSION"),
      leetcode_csrf_token: nullable_env("LEETCODE_CSRF_TOKEN"),
      leetcode_auth_username: nullable_env("LEETCODE_AUTH_USERNAME"),
      github_token: nullable_env("GITHUB_TOKEN"),
      dry_run: cli_options[:dry_run] || boolean_env("DRY_RUN", false),
      verbose: cli_options[:verbose] || boolean_env("VERBOSE", false),
      request_timeout_ms: integer_env("REQUEST_TIMEOUT_MS", 20_000),
      recent_accepted_limit: integer_env("RECENT_ACCEPTED_LIMIT", 20),
      sync_interval_minutes: integer_env("SYNC_INTERVAL_MINUTES", 1_440),
      state_file_path: state_file_path,
      lock_file_path: lock_file_path,
      tmp_dir: Path.join(project_root, ".tmp"),
      push_after_each_commit: boolean_env("PUSH_AFTER_EACH_COMMIT", true),
      auto_clone_target_repo: boolean_env("AUTO_CLONE_TARGET_REPO", true),
      allow_dirty_target_repo: boolean_env("ALLOW_DIRTY_TARGET_REPO", false),
      stop_on_push_failure: boolean_env("STOP_ON_PUSH_FAILURE", true),
      backfill: cli_options[:backfill]
    }
  end

  defp normalize_runtime_path(path, project_root) do
    if Path.type(path) == :absolute do
      Path.expand(path)
    else
      project_root
      |> Path.join(path)
      |> Path.expand()
    end
  end

  defp default(nil, fallback), do: fallback
  defp default(value, _fallback), do: value

  defp string_env(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> value
    end
  end

  defp nullable_env(name) do
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end

  defp boolean_env(name, default) do
    case nullable_env(name) do
      nil -> default
      value -> String.downcase(value) in ["1", "true", "yes", "on"]
    end
  end

  defp integer_env(name, default) do
    case nullable_env(name) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {parsed, ""} -> parsed
          _ -> raise ArgumentError, "Invalid integer in #{name}: #{inspect(value)}"
        end
    end
  end
end
