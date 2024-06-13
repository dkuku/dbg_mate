defmodule DbgMate.Custom do
  @moduledoc """
  dbg functions that use custom formatter and function to handle the result
  """

  @doc """
  You can pass custom function and a formatter string.

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

  def dbg({op, meta, _data} = ast, options, _env) when op in @valid_ops do
    compiled_format = DbgMate.Formatter.compile(options[:format])
    label = ast |> Macro.to_string() |> String.replace(~r/\s\s+/, " ")

    quote do
      start_time = System.monotonic_time()
      result = unquote(ast)
      end_time = System.monotonic_time()

      IO.write(
        DbgMate.Formatter.format(
          unquote(compiled_format),
          unquote(meta),
          start_time,
          end_time,
          unquote(label),
          result
        )
      )

      result
    end
  end

  def dbg(ast, _, _) do
    ast
  end
end
