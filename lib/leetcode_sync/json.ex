defmodule LeetCodeSync.JSON do
  @moduledoc """
  Small wrapper around Jason so encoding and decoding behavior is centralized.
  """

  @spec decode!(binary()) :: map() | list()
  def decode!(payload) when is_binary(payload), do: Jason.decode!(payload)

  @spec encode_pretty!(term()) :: binary()
  def encode_pretty!(payload), do: Jason.encode!(payload, pretty: true)
end
