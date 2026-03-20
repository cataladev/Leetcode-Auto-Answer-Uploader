defmodule LeetCodeSync.Sync do
  @moduledoc """
  Coordinates stateful LeetCode polling, repo mutations, and per-problem git commits.
  """

  alias LeetCodeSync.{FileLock, FileUtils, Git, LeetCodeClient, SolutionWriter, State}
  require Logger

  @spec run(LeetCodeSync.Config.t()) :: {:ok, map()} | {:error, term()}
  def run(config) do
    File.mkdir_p!(config.tmp_dir)

    FileLock.with_lock(config.lock_file_path, fn ->
      with {:ok, repo} <- Git.ensure_repo_ready(config),
           {:ok, state} <- State.load(config.state_file_path),
           {:ok, submissions} <- LeetCodeClient.fetch_recent_accepted_submissions(config) do
        unique_submissions =
          submissions
          |> Enum.sort_by(& &1.timestamp, :desc)
          |> Enum.uniq_by(& &1.title_slug)
          |> Enum.sort_by(& &1.timestamp)

        process_submissions(unique_submissions, state, repo, config, summary(config))
      end
    end)
  end

  @spec healthcheck(LeetCodeSync.Config.t()) :: {:ok, map()}
  def healthcheck(config) do
    {:ok,
     %{
       status: :ok,
       project_root: config.project_root,
       target_repo_local_path: config.target_repo_local_path,
       git_available: Git.available?(),
       lock_file_path: config.lock_file_path,
       state_file_path: config.state_file_path,
       authenticated_submission_fetch: not is_nil(config.leetcode_session)
     }}
  end

  defp process_submissions([], state, _repo, config, summary) do
    final_state = State.mark_run_complete(state)

    unless config.dry_run do
      State.save!(config.state_file_path, final_state)
    end

    {:ok, summary}
  end

  defp process_submissions([problem | rest], state, repo, config, summary) do
    cond do
      State.processed?(state, problem.title_slug) ->
        process_submissions(rest, state, repo, config, skip(summary, problem, :already_processed))

      SolutionWriter.problem_present?(repo.path, problem.title_slug, problem.title) ->
        updated_state =
          State.mark_processed(state, problem, %{
            folder_name: FileUtils.safe_folder_name(problem.title),
            commit_message: "Add LeetCode solution: #{problem.title}",
            commit_hash: nil,
            push_status: "already_present",
            submitted_code_retrieved: false
          })

        unless config.dry_run do
          State.save!(config.state_file_path, updated_state)
        end

        process_submissions(
          rest,
          updated_state,
          repo,
          config,
          skip(summary, problem, :already_in_repo)
        )

      true ->
        sync_problem(problem, rest, state, repo, config, summary)
    end
  end

  defp sync_problem(problem, rest, state, repo, config, summary) do
    question = fetch_question_or_fallback(config, problem)
    submission_result = LeetCodeClient.fetch_latest_submission_code(config, problem.title_slug)

    case SolutionWriter.stage_problem(repo.path, problem, question, submission_result, config) do
      {:skip, reason} ->
        updated_state =
          State.mark_processed(state, problem, %{
            folder_name: FileUtils.safe_folder_name(question.title || problem.title),
            commit_message: "Add LeetCode solution: #{question.title || problem.title}",
            commit_hash: nil,
            push_status: "already_present",
            submitted_code_retrieved: false
          })

        unless config.dry_run do
          State.save!(config.state_file_path, updated_state)
        end

        process_submissions(rest, updated_state, repo, config, skip(summary, problem, reason))

      {:error, reason} ->
        {:error,
         %{
           summary
           | errors: summary.errors ++ [%{problem: problem.title, reason: inspect(reason)}]
         }}

      {:ok, prepared} when prepared.dry_run ->
        process_submissions(rest, state, repo, config, dry_run(summary, prepared.metadata))

      {:ok, prepared} ->
        commit_message = "Add LeetCode solution: #{prepared.metadata["title"]}"

        case Git.commit_problem(repo.path, prepared.commit_paths, commit_message, config) do
          {:ok, git_result} ->
            updated_state =
              State.mark_processed(state, problem, %{
                folder_name: prepared.folder_name,
                commit_message: commit_message,
                commit_hash: git_result.commit_hash,
                push_status: git_result.push_status,
                submitted_code_retrieved: prepared.metadata["submitted_code_retrieved"]
              })

            State.save!(config.state_file_path, updated_state)

            process_submissions(
              rest,
              updated_state,
              repo,
              config,
              processed(summary, prepared.metadata, git_result)
            )

          {:error, {:push_failed, reason, commit_hash}} ->
            updated_state =
              State.mark_processed(state, problem, %{
                folder_name: prepared.folder_name,
                commit_message: commit_message,
                commit_hash: commit_hash,
                push_status: "pending_push",
                submitted_code_retrieved: prepared.metadata["submitted_code_retrieved"]
              })

            State.save!(config.state_file_path, updated_state)

            push_summary =
              %{
                problem: prepared.metadata["title"],
                commit_hash: commit_hash,
                reason: inspect(reason)
              }

            if config.stop_on_push_failure do
              {:error, %{summary | errors: summary.errors ++ [push_summary]}}
            else
              process_submissions(
                rest,
                updated_state,
                repo,
                config,
                %{summary | errors: summary.errors ++ [push_summary]}
              )
            end

          {:error, reason} ->
            SolutionWriter.rollback(prepared)
            Git.unstage_paths(repo.path, prepared.commit_paths, config)

            {:error,
             %{
               summary
               | errors: summary.errors ++ [%{problem: problem.title, reason: inspect(reason)}]
             }}
        end
    end
  end

  defp fetch_question_or_fallback(config, problem) do
    case LeetCodeClient.fetch_question_details(config, problem.title_slug) do
      {:ok, question} ->
        question

      {:error, reason} ->
        Logger.warning(
          "Question detail lookup failed for #{problem.title_slug}: #{inspect(reason)}"
        )

        %{
          frontend_id: nil,
          title: problem.title,
          title_slug: problem.title_slug,
          difficulty: "Unknown",
          topic_tags: []
        }
    end
  end

  defp summary(config) do
    %{
      dry_run: config.dry_run,
      processed: [],
      skipped: [],
      errors: []
    }
  end

  defp processed(summary, metadata, git_result) do
    %{
      summary
      | processed:
          summary.processed ++ [%{title: metadata["title"], commit_hash: git_result.commit_hash}]
    }
  end

  defp skip(summary, problem, reason) do
    %{summary | skipped: summary.skipped ++ [%{title: problem.title, reason: reason}]}
  end

  defp dry_run(summary, metadata) do
    %{summary | processed: summary.processed ++ [%{title: metadata["title"], dry_run: true}]}
  end
end
