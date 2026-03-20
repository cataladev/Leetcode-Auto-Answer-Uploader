defmodule LeetCodeSync.MixProject do
  use Mix.Project

  def project do
    [
      app: :leetcode_sync,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: LeetCodeSync.CLI]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {LeetCodeSync.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5.17"},
      {:jason, "~> 1.4"}
    ]
  end
end
