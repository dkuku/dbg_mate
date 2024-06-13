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

  @valid_ops [:def, :defp, :if, :unless, :case, :cond, :with, :=, :for, :|>]

  def dbg([do: {op, meta, clauses}], options, env) do
    [do: dbg({op, meta, clauses}, options, env)]
  end

  def dbg({op, meta, clauses}, options, env) when op in [:__block__, :def, :defmodule] do
    clauses = Enum.map(clauses, &dbg(&1, options, env))
    {op, meta, clauses}
  end

  def dbg({op, meta, _data} = ast, _options, _env) when op in @valid_ops do
    label = ast |> Macro.to_string() |> String.replace(~r/\s\s+/, " ")
    label = "#{meta[:line]} | " <> label

    quote do
      result = unquote(ast)

      IO.inspect(result, label: unquote(label))
    end
  end

  def dbg(ast, _, _) do
    ast
  end

  @doc """
  Similar to previous one that it wraps your code in IO.inspect calls used for sho
  wing the intermediate results
  and additionally shows the time it took to execute every line.

  To use it just set the config value in config or run this before your dbg call
  """
  def dbg_tc([do: {op, meta, clauses}], options, env) do
    [do: dbg_tc({op, meta, clauses}, options, env)]
  end

  def dbg_tc({op, meta, clauses}, options, env) when op in [:__block__, :def, :defmodule] do
    clauses = Enum.map(clauses, &dbg_tc(&1, options, env))
    {op, meta, clauses}
  end

  def dbg_tc({op, meta, _data} = ast, _options, _env) when op in @valid_ops do
    label = ast |> Macro.to_string() |> String.replace(~r/\s\s+/, " ")
    line = String.pad_leading("#{meta[:line]} |", 5)

    quote do
      start_time = System.monotonic_time()
      result = unquote(ast)
      end_time = System.monotonic_time()
      duration = DbgMate.Formatter.get_duration_string(start_time, end_time)

      IO.inspect(result, label: unquote(line) <> duration <> " " <> unquote(label))
    end
  end

  def dbg_tc(ast, _, _) do
    ast
  end
end
