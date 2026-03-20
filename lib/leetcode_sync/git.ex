defmodule LeetCodeSync.Git do
  @moduledoc """
  Git helpers for the target solutions repository.
  """

  alias LeetCodeSync.Config

  @spec ensure_repo_ready(Config.t()) :: {:ok, map()} | {:error, term()}
  def ensure_repo_ready(config) do
    File.mkdir_p!(config.tmp_dir)

    with :ok <- ensure_git_available(),
         :ok <- ensure_repo_present(config),
         :ok <- ensure_origin_remote(config),
         :ok <- checkout_branch(config),
         :ok <- ensure_clean_worktree(config),
         :ok <- pull_latest(config),
         :ok <- push_pending_local_commits(config) do
      {:ok, %{path: config.target_repo_local_path, branch: config.git_branch}}
    end
  end

  @spec commit_problem(Path.t(), [String.t()], String.t(), Config.t()) ::
          {:ok, map()} | {:error, term()}
  def commit_problem(repo_path, paths, commit_message, config) do
    with :ok <- run_ok(repo_path, ["add" | paths], config),
         :ok <- commit(repo_path, commit_message, config),
         {:ok, commit_hash} <- rev_parse_head(repo_path, config) do
      case maybe_push(repo_path, config) do
        :ok ->
          {:ok, %{commit_hash: commit_hash, push_status: "pushed"}}

        {:error, reason} ->
          {:error, {:push_failed, reason, commit_hash}}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec unstage_paths(Path.t(), [String.t()], Config.t()) :: :ok
  def unstage_paths(repo_path, paths, config) do
    _ = run(repo_path, ["reset", "HEAD" | paths], config)
    :ok
  end

  @spec available?() :: boolean()
  def available?, do: not is_nil(System.find_executable("git"))

  defp ensure_git_available do
    if available?(), do: :ok, else: {:error, :git_not_available}
  end

  defp ensure_repo_present(config) do
    repo_path = config.target_repo_local_path

    cond do
      File.dir?(Path.join(repo_path, ".git")) ->
        :ok

      File.exists?(repo_path) ->
        {:error, {:target_repo_not_git_repository, repo_path}}

      config.auto_clone_target_repo ->
        clone_repo(config)

      true ->
        {:error, {:target_repo_missing, repo_path}}
    end
  end

  defp clone_repo(config) do
    File.mkdir_p!(Path.dirname(config.target_repo_local_path))

    clone_url = authenticated_remote_url(config) || config.target_repo_url

    with :ok <-
           run_ok(
             Path.dirname(config.target_repo_local_path),
             ["clone", clone_url, config.target_repo_local_path],
             config
           ) do
      if clone_url != config.target_repo_url do
        run_ok(
          config.target_repo_local_path,
          ["remote", "set-url", "origin", config.target_repo_url],
          config
        )
      else
        :ok
      end
    end
  end

  defp checkout_branch(config) do
    repo_path = config.target_repo_local_path

    cond do
      branch_exists?(repo_path, config.git_branch, config) ->
        run_ok(repo_path, ["checkout", config.git_branch], config)

      remote_branch_exists?(repo_path, config.git_branch, config) ->
        run_ok(
          repo_path,
          ["checkout", "-b", config.git_branch, "--track", "origin/#{config.git_branch}"],
          config
        )

      true ->
        run_ok(repo_path, ["checkout", "-B", config.git_branch], config)
    end
  end

  defp ensure_clean_worktree(config) do
    case run(config.target_repo_local_path, ["status", "--porcelain"], config) do
      {:ok, ""} ->
        :ok

      {:ok, _output} when config.allow_dirty_target_repo ->
        :ok

      {:ok, output} ->
        {:error, {:dirty_target_repo, output}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp pull_latest(config) do
    if remote_branch_exists?(config.target_repo_local_path, config.git_branch, config) do
      run_ok(
        config.target_repo_local_path,
        ["pull", "--ff-only", "origin", config.git_branch],
        config
      )
    else
      :ok
    end
  end

  defp push_pending_local_commits(config) do
    case run(config.target_repo_local_path, ["status", "--porcelain", "--branch"], config) do
      {:ok, output} ->
        if String.contains?(output, "[ahead ") do
          maybe_push(config.target_repo_local_path, config)
        else
          :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp commit(repo_path, commit_message, config) do
    run_ok(
      repo_path,
      [
        "-c",
        "user.name=#{config.commit_author_name}",
        "-c",
        "user.email=#{config.commit_author_email}",
        "commit",
        "-m",
        commit_message
      ],
      config
    )
  end

  defp rev_parse_head(repo_path, config) do
    run(repo_path, ["rev-parse", "HEAD"], config)
  end

  defp maybe_push(_repo_path, %Config{push_after_each_commit: false}), do: :ok
  defp maybe_push(_repo_path, %Config{dry_run: true}), do: :ok

  defp maybe_push(repo_path, config) do
    args =
      case authenticated_remote_url(config) do
        nil -> ["push", "origin", config.git_branch]
        remote_url -> ["push", remote_url, "HEAD:#{config.git_branch}"]
      end

    case run(repo_path, args, config) do
      {:ok, _output} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_origin_remote(config) do
    repo_path = config.target_repo_local_path

    case run(repo_path, ["remote", "get-url", "origin"], config) do
      {:ok, _url} ->
        :ok

      {:error, _reason} ->
        run_ok(repo_path, ["remote", "add", "origin", config.target_repo_url], config)
    end
  end

  defp branch_exists?(repo_path, branch, config) do
    match?(
      {:ok, _},
      run(repo_path, ["show-ref", "--verify", "--quiet", "refs/heads/#{branch}"], config)
    )
  end

  defp remote_branch_exists?(repo_path, branch, config) do
    match?(
      {:ok, _},
      run(repo_path, ["ls-remote", "--exit-code", "--heads", "origin", branch], config)
    )
  end

  defp authenticated_remote_url(%Config{github_token: nil}), do: nil
  defp authenticated_remote_url(%Config{github_token: ""}), do: nil

  defp authenticated_remote_url(config) do
    case URI.parse(config.target_repo_url) do
      %URI{scheme: "https", host: "github.com"} = uri ->
        uri
        |> Map.put(:userinfo, "x-access-token:#{config.github_token}")
        |> URI.to_string()

      _other ->
        nil
    end
  end

  defp run_ok(repo_path, args, config) do
    case run(repo_path, args, config) do
      {:ok, _output} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp run(repo_path, args, config) do
    options = [
      cd: repo_path,
      env: [{"TMPDIR", config.tmp_dir}],
      stderr_to_stdout: true
    ]

    case System.cmd("git", args, options) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _status} -> {:error, {:git_command_failed, args, String.trim(output)}}
    end
  end
end
