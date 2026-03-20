defmodule LeetCodeSync.Sync do
  @moduledoc """
  Placeholder sync orchestrator. Core sync logic is added in later milestones.
  """

  @spec run(LeetCodeSync.Config.t()) :: {:ok, map()}
  def run(config) do
    {:ok,
     %{
       mode: :scaffold,
       project_root: config.project_root,
       dry_run: config.dry_run,
       leetcode_username: config.leetcode_username
     }}
  end

  @spec healthcheck(LeetCodeSync.Config.t()) :: {:ok, map()}
  def healthcheck(config) do
    {:ok,
     %{
       status: :ok,
       project_root: config.project_root,
       target_repo_local_path: config.target_repo_local_path
     }}
  end
end
