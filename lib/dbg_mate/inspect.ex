defmodule DbgMate.Inspect do
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
    label = "#{meta[:line]} " <> label

    quote do
      result = unquote(ast)

      IO.inspect(result, label: unquote(label))
    end
  end

  def dbg({_op, _, _} = ast, _, _) do
    ast
  end

  def dbg_tc([do: {op, meta, clauses}], options, env) do
    [do: dbg({op, meta, clauses}, options, env)]
  end

  def dbg_tc({op, meta, clauses}, options, env) when op in [:__block__, :def, :defmodule] do
    clauses = Enum.map(clauses, &dbg(&1, options, env))
    {op, meta, clauses}
  end

  def dbg_tc({op, _meta, _data} = ast, _options, _env) when op in @valid_ops do
    label = ast |> Macro.to_string() |> String.replace(~r/\s\s+/, " ")

    quote do
      start_time = System.monotonic_time()
      result = unquote(ast)
      duration = DbgMate.Inspect.get_duration_string(start_time)

      IO.inspect(result, label: duration <> " " <> unquote(label))
    end
  end

  def dbg_tc({_op, _, _} = ast, _, _) do
    ast
  end

  def get_duration_string(start_time) do
    end_time = System.monotonic_time()
    duration = end_time - start_time

    case System.convert_time_unit(duration, :native, :microsecond) do
      duration when duration < 1000 -> "#{duration}us"
      duration when duration < 1_000_000 -> "#{div(duration, 1000)}ms"
      duration when duration < 1_000_000_000 -> "#{div(duration, 1_000_000)}s "
    end
    |> String.pad_leading(6)
  end
end
