defmodule DbgMate.Inspect do
  @moduledoc """
  dbg functtions that use IO.inspect() do display results
  """

  @doc """
  Wraps your code in IO.inspect calls used for showing the intermediate results.
  The difference between the upstream dbg function is that it displays as the code
  is executed and is not waiting until a block of code finishes.
  It also works with whole modules and functions

  ```elixir
  defmodule X do
    def y do: :z
  end
  |> dbg

  defmodule Y do
    def x do
      :z
    end
    |> dbg
  end
  ```
  """

  def install do
    Application.put_env(:elixir, :dbg_callback, {DbgMate.Inspect, :dbg, []})
  end

  def install(:dbg_tc) do
    Application.put_env(:elixir, :dbg_callback, {DbgMate.Inspect, :dbg_tc, []})
  end

  def dbg(operation, options, env) do
    options = Keyword.put(options, :format, "$line | $code: $result\n")
    DbgMate.Custom.dbg(operation, options, env)
  end

  @doc """
  Similar to previous one that it wraps your code in IO.inspect calls used for sho
  wing the intermediate results
  and additionally shows the time it took to execute every line.

  To use it just set the config value in config or run this before your dbg call
  """
  def dbg_tc(operation, options, env) do
    options = Keyword.put(options, :format, "$line | $duration | $code: $result\n")
    DbgMate.Custom.dbg(operation, options, env)
  end
end
