defmodule LeetCodeSync.SolutionWriter do
  @moduledoc """
  Writes solution folders, metadata, and the committed repo manifest.
  """

  alias LeetCodeSync.{Config, FileUtils, JSON}

  @manifest_relative_path Path.join(".leetcode-sync", "solutions.json")

  @spec stage_problem(Path.t(), map(), map(), {:ok, map()} | {:error, term()}, Config.t()) ::
          {:ok, map()} | {:skip, term()} | {:error, term()}
  def stage_problem(repo_path, problem, question, submission_result, config) do
    folder_name = FileUtils.safe_folder_name(question.title || problem.title)
    folder_path = Path.join(repo_path, folder_name)
    manifest_path = Path.join(repo_path, @manifest_relative_path)
    manifest = load_manifest(manifest_path)
    title_slug = question.title_slug || problem.title_slug

    cond do
      Map.has_key?(manifest["solutions"], title_slug) ->
        {:skip, :already_recorded}

      File.exists?(folder_path) ->
        {:skip, :folder_already_exists}

      config.dry_run ->
        {:ok,
         %{
           folder_name: folder_name,
           folder_path: folder_path,
           manifest_path: manifest_path,
           commit_paths: [folder_name, @manifest_relative_path],
           metadata:
             build_metadata(problem, question, submission_result, folder_name, config.solution_file_extension),
           rollback: nil,
           dry_run: true
         }}

      true ->
        write_problem(problem, question, submission_result, folder_name, folder_path, manifest_path, manifest, config)
    end
  end

  @spec rollback(map()) :: :ok
  def rollback(%{rollback: nil}), do: :ok

  def rollback(%{rollback: rollback}) do
    if rollback.folder_created and File.exists?(rollback.folder_path) do
      File.rm_rf!(rollback.folder_path)
    end

    restore_manifest(rollback.manifest_path, rollback.previous_manifest_contents)
    :ok
  end

  @spec problem_present?(Path.t(), String.t(), String.t()) :: boolean()
  def problem_present?(repo_path, title_slug, title) do
    folder_path = Path.join(repo_path, FileUtils.safe_folder_name(title))
    manifest_path = Path.join(repo_path, @manifest_relative_path)
    manifest = load_manifest(manifest_path)

    Map.has_key?(manifest["solutions"], title_slug) or File.exists?(folder_path)
  end

  defp write_problem(problem, question, submission_result, folder_name, folder_path, manifest_path, manifest, config) do
    previous_manifest_contents =
      if File.exists?(manifest_path) do
        File.read!(manifest_path)
      else
        nil
      end

    metadata = build_metadata(problem, question, submission_result, folder_name, config.solution_file_extension)

    try do
      File.mkdir_p!(folder_path)

      solution_filename = metadata["solution_file"]

      write_file(Path.join(folder_path, solution_filename), solution_contents(problem, submission_result, metadata, config))
      write_file(Path.join(folder_path, "problem.json"), JSON.encode_pretty!(metadata) <> "\n")
      write_file(Path.join(folder_path, "README.md"), render_template(config.project_root, "problem_readme.eex", %{metadata: metadata}))

      updated_manifest =
        put_in(
          manifest,
          ["solutions", metadata["title_slug"]],
          %{
            "title" => metadata["title"],
            "title_slug" => metadata["title_slug"],
            "folder_name" => folder_name,
            "solution_file" => solution_filename,
            "commit_message" => "Add LeetCode solution: #{metadata["title"]}",
            "submitted_code_retrieved" => metadata["submitted_code_retrieved"],
            "synced_at" => metadata["synced_at"]
          }
        )

      FileUtils.ensure_directory!(manifest_path)
      File.write!(manifest_path, JSON.encode_pretty!(updated_manifest) <> "\n")

      {:ok,
       %{
         folder_name: folder_name,
         folder_path: folder_path,
         manifest_path: manifest_path,
         commit_paths: [folder_name, @manifest_relative_path],
         metadata: metadata,
         rollback: %{
           folder_created: true,
           folder_path: folder_path,
           manifest_path: manifest_path,
           previous_manifest_contents: previous_manifest_contents
         },
         dry_run: false
       }}
    rescue
      error ->
        restore_manifest(manifest_path, previous_manifest_contents)

        if File.exists?(folder_path) do
          File.rm_rf!(folder_path)
        end

        {:error, {:solution_write_failed, Exception.message(error)}}
    end
  end

  defp build_metadata(problem, question, submission_result, folder_name, configured_extension) do
    submission = if match?({:ok, _}, submission_result), do: elem(submission_result, 1), else: %{}
    language = submission[:language]
    extension = FileUtils.solution_extension(language, configured_extension)
    synced_at = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      "title" => question.title || problem.title,
      "title_slug" => question.title_slug || problem.title_slug,
      "frontend_id" => question.frontend_id,
      "difficulty" => question.difficulty || "Unknown",
      "topic_tags" => question.topic_tags || [],
      "leetcode_url" => problem.url,
      "folder_name" => folder_name,
      "solution_file" => "solution.#{extension}",
      "language" => language,
      "submission_id" => submission[:submission_id],
      "submitted_code_retrieved" => match?({:ok, _}, submission_result),
      "submission_fetch_status" => submission_status(submission_result),
      "placeholder_reason" => placeholder_reason(submission_result),
      "synced_at" => synced_at
    }
  end

  defp submission_status({:ok, _submission}), do: "retrieved"
  defp submission_status({:error, _reason}), do: "placeholder"

  defp placeholder_reason({:ok, _submission}), do: nil
  defp placeholder_reason({:error, reason}), do: inspect(reason)

  defp solution_contents(_problem, {:ok, submission}, _metadata, _config), do: submission[:submitted_code]

  defp solution_contents(problem, {:error, reason}, metadata, config) do
    render_template(
      config.project_root,
      "solution_placeholder.eex",
      %{
        title: metadata["title"],
        title_slug: metadata["title_slug"],
        leetcode_url: problem.url,
        reason: inspect(reason)
      }
    )
  end

  defp load_manifest(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> JSON.decode!()
      |> normalize_manifest()
    else
      default_manifest()
    end
  rescue
    _error ->
      default_manifest()
  end

  defp normalize_manifest(manifest) do
    default_manifest()
    |> Map.merge(manifest)
    |> Map.update!("solutions", fn value -> value || %{} end)
  end

  defp default_manifest do
    %{"version" => 1, "solutions" => %{}}
  end

  defp restore_manifest(manifest_path, nil) do
    if File.exists?(manifest_path) do
      File.rm(manifest_path)
    end

    :ok
  end

  defp restore_manifest(manifest_path, previous_manifest_contents) do
    FileUtils.ensure_directory!(manifest_path)
    File.write!(manifest_path, previous_manifest_contents)
  end

  defp write_file(path, contents) do
    FileUtils.ensure_directory!(path)
    File.write!(path, contents <> "")
  end

  defp render_template(project_root, template_name, assigns) do
    [project_root, "priv", "templates", template_name]
    |> Path.join()
    |> EEx.eval_file(Map.to_list(assigns))
  end
end
