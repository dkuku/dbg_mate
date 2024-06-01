defmodule DbgMate.Backport do
  @moduledoc """
  This module includes features that will be enabled in elixir 1.18.
  plus a commit for `with` that was not merged.

  Backport module currently includes dbg implementation for:

  - pipes
  - binary operators: and, or, ||, &&
  - code blocks wrapped in brackets
  - conditions: case, cond, if, unless, with

  To use it just set the config value in config or run this before your dbg call
  Application.put_env(:elixir, :dbg_callback, {DbgMate,Backport, :dbg, []})
  """
  @typedoc "Abstract Syntax Tree (AST)"
  @type t :: input

  @typedoc "The inputs of a macro"
  @type input ::
          input_expr
          | {input, input}
          | [input]
          | atom
          | number
          | binary

  @type metadata :: keyword
  @typep input_expr :: {input_expr | atom, metadata, atom | [input]}

  @type captured_remote_function :: fun
  @typedoc "The output of a macro"
  @type output ::
          output_expr
          | {output, output}
          | [output]
          | atom
          | number
          | binary
          | captured_remote_function
          | pid

  @typep output_expr :: {output_expr | atom, metadata, atom | [output]}

  @doc """
  Default backend for `Kernel.dbg/2`.

  This function provides a default backend for `Kernel.dbg/2`. See the
  `Kernel.dbg/2` documentation for more information.

  This function:

    * prints information about the given `env`
    * prints information about `code` and its returned value (using `opts` to inspect terms)
    * returns the value returned by evaluating `code`

  You can call this function directly to build `Kernel.dbg/2` backends that fall back
  to this function.

  This function raises if the context of the given `env` is `:match` or `:guard`.
  """
  @doc since: "1.14.0"
  @spec dbg(t, t, Macro.Env.t()) :: t
  def dbg(code, options, %Macro.Env{} = env) do
    case env.context do
      :match ->
        raise ArgumentError,
              "invalid expression in match, dbg is not allowed in patterns " <>
                "such as function clauses, case clauses or on the left side of the = operator"

      :guard ->
        raise ArgumentError,
              "invalid expression in guard, dbg is not allowed in guards. " <>
                "To learn more about guards, visit: https://hexdocs.pm/elixir/patterns-and-guards.html"

      _ ->
        :ok
    end

    header = dbg_format_header(env)

    quote do
      to_debug = unquote(dbg_ast_to_debuggable(code, env))
      unquote(__MODULE__).__dbg__(unquote(header), to_debug, unquote(options))
    end
  end

  # Pipelines.
  defp dbg_ast_to_debuggable({:|>, _meta, _args} = pipe_ast, _env) do
    value_var = Macro.unique_var(:value, __MODULE__)
    values_acc_var = Macro.unique_var(:values, __MODULE__)

    [start_ast | rest_asts] = asts = for {ast, 0} <- Macro.unpipe(pipe_ast), do: ast
    rest_asts = Enum.map(rest_asts, &Macro.pipe(value_var, &1, 0))

    initial_acc =
      quote do
        unquote(value_var) = unquote(start_ast)
        unquote(values_acc_var) = [unquote(value_var)]
      end

    values_ast =
      for step_ast <- rest_asts, reduce: initial_acc do
        ast_acc ->
          quote do
            unquote(ast_acc)
            unquote(value_var) = unquote(step_ast)
            unquote(values_acc_var) = [unquote(value_var) | unquote(values_acc_var)]
          end
      end

    quote do
      unquote(values_ast)

      {:pipe, unquote(Macro.escape(asts)), Enum.reverse(unquote(values_acc_var))}
    end
  end

  dbg_decomposed_binary_operators = [:&&, :||, :and, :or]

  # Logic operators.
  defp dbg_ast_to_debuggable({op, _meta, [_left, _right]} = ast, _env)
       when op in unquote(dbg_decomposed_binary_operators) do
    acc_var = Macro.unique_var(:acc, __MODULE__)
    result_var = Macro.unique_var(:result, __MODULE__)

    quote do
      unquote(acc_var) = []
      unquote(dbg_boolean_tree(ast, acc_var, result_var))
      {:logic_op, Enum.reverse(unquote(acc_var))}
    end
  end

  defp dbg_ast_to_debuggable({:__block__, _meta, exprs} = ast, _env) when exprs != [] do
    acc_var = Macro.unique_var(:acc, __MODULE__)
    result_var = Macro.unique_var(:result, __MODULE__)

    quote do
      unquote(acc_var) = []
      unquote(dbg_block(ast, acc_var, result_var))
      {:block, Enum.reverse(unquote(acc_var)), unquote(result_var)}
    end
  end

  defp dbg_ast_to_debuggable({:case, _meta, [expr, [do: clauses]]} = ast, _env) do
    clauses_returning_index =
      Enum.with_index(clauses, fn {:->, meta, [left, right]}, index ->
        {:->, meta, [left, {right, index}]}
      end)

    quote do
      expr = unquote(expr)

      {result, clause_index} =
        case expr do
          unquote(clauses_returning_index)
        end

      {:case, unquote(Macro.escape(ast)), expr, clause_index, result}
    end
  end

  defp dbg_ast_to_debuggable({:with, meta, args} = ast, _env) do
    {opts, clauses} = List.pop_at(args, -1)

    acc_ref_var = Macro.unique_var(:acc_ref, __MODULE__)

    modified_clauses =
      Enum.flat_map(clauses, fn
        # We only detail assignments and pattern-matching clauses that
        # can be helpful to understand how the result is constructed.
        {symbol, _meta, [left, right]} when symbol in [:<-, :=] ->
          quote do
            [
              value = unquote(right),
              Process.put(unquote(acc_ref_var), [
                {unquote(Macro.escape(right)), value} | Process.get(unquote(acc_ref_var))
              ]),
              unquote(symbol)(unquote(left), value)
            ]
          end

        # Other expressions like side effects are omitted.
        expr ->
          [expr]
      end)

    modified_with_ast = {:with, meta, modified_clauses ++ [opts]}

    quote do
      unquote(acc_ref_var) = make_ref()
      Process.put(unquote(acc_ref_var), [])

      value = unquote(modified_with_ast)

      acc = Process.get(unquote(acc_ref_var))
      Process.delete(unquote(acc_ref_var))
      {:with, unquote(Macro.escape(ast)), Enum.reverse(acc), value}
    end
  end

  defp dbg_ast_to_debuggable({:cond, _meta, [[do: clauses]]} = ast, _env) do
    modified_clauses =
      Enum.with_index(clauses, fn {:->, _meta, [[left], right]}, index ->
        hd(
          quote do
            clause_value = unquote(left) ->
              {unquote(Macro.escape(left)), clause_value, unquote(index), unquote(right)}
          end
        )
      end)

    quote do
      {clause_ast, clause_value, clause_index, value} =
        cond do
          unquote(modified_clauses)
        end

      {:cond, unquote(Macro.escape(ast)), clause_ast, clause_value, clause_index, value}
    end
  end

  defp dbg_ast_to_debuggable({op, meta, [condition_ast, clauses]} = ast, env)
       when op in [:if, :unless] do
    case Macro.Env.lookup_import(env, {op, 2}) do
      [macro: Kernel] ->
        condition_result_var = Macro.unique_var(:condition_result, __MODULE__)

        quote do
          unquote(condition_result_var) = unquote(condition_ast)
          result = unquote({op, meta, [condition_result_var, clauses]})

          {unquote(op), unquote(Macro.escape(ast)), unquote(Macro.escape(condition_ast)),
           unquote(condition_result_var), result}
        end

      _ ->
        quote do: {:value, unquote(Macro.escape(ast)), unquote(ast)}
    end
  end

  # Any other AST.
  defp dbg_ast_to_debuggable(ast, _env) do
    quote do: {:value, unquote(Macro.escape(ast)), unquote(ast)}
  end

  # This is a binary operator. We replace the left side with a recursive call to
  # this function to decompose it, and then execute the operation and add it to the acc.
  defp dbg_boolean_tree({op, _meta, [left, right]} = ast, acc_var, result_var)
       when op in unquote(dbg_decomposed_binary_operators) do
    replaced_left = dbg_boolean_tree(left, acc_var, result_var)

    quote do
      unquote(result_var) = unquote(op)(unquote(replaced_left), unquote(right))

      unquote(acc_var) = [
        {unquote(Macro.escape(ast)), unquote(result_var)} | unquote(acc_var)
      ]

      unquote(result_var)
    end
  end

  # This is finally an expression, so we assign "result = expr", add it to the acc, and
  # return the result.
  defp dbg_boolean_tree(ast, acc_var, result_var) do
    quote do
      unquote(result_var) = unquote(ast)
      unquote(acc_var) = [{unquote(Macro.escape(ast)), unquote(result_var)} | unquote(acc_var)]
      unquote(result_var)
    end
  end

  defp dbg_block({:__block__, meta, exprs}, acc_var, result_var) do
    modified_exprs =
      Enum.map(exprs, fn expr ->
        quote do
          unquote(result_var) = unquote(expr)

          unquote(acc_var) = [
            {unquote(Macro.escape(expr)), unquote(result_var)} | unquote(acc_var)
          ]
        end
      end)

    {:__block__, meta, modified_exprs}
  end

  # Made public to be called from Macro.dbg/3, so that we generate as little code
  # as possible and call out into a function as soon as we can.
  @doc false
  def __dbg__(header_string, to_debug, options) do
    {print_location?, options} = Keyword.pop(options, :print_location, true)
    syntax_colors = if IO.ANSI.enabled?(), do: IO.ANSI.syntax_colors(), else: []
    options = Keyword.merge([width: 80, pretty: true, syntax_colors: syntax_colors], options)

    {formatted, result} = dbg_format_ast_to_debug(to_debug, options)

    formatted =
      if print_location? do
        [:cyan, :italic, header_string, :reset, "\n", formatted, "\n"]
      else
        [formatted, "\n"]
      end

    ansi_enabled? = options[:syntax_colors] != []
    :ok = IO.write(IO.ANSI.format(formatted, ansi_enabled?))

    result
  end

  defp dbg_format_ast_to_debug({:pipe, code_asts, values}, options) do
    result = List.last(values)
    code_strings = Enum.map(code_asts, &to_string_with_colors(&1, options))
    [{first_ast, first_value} | asts_with_values] = Enum.zip(code_strings, values)
    first_formatted = [dbg_format_ast(first_ast), " ", inspect(first_value, options), ?\n]

    rest_formatted =
      Enum.map(asts_with_values, fn {code_ast, value} ->
        [:faint, "|> ", :reset, dbg_format_ast(code_ast), " ", inspect(value, options), ?\n]
      end)

    {[first_formatted | rest_formatted], result}
  end

  defp dbg_format_ast_to_debug({:logic_op, components}, options) do
    {_ast, final_value} = List.last(components)

    formatted =
      Enum.map(components, fn {ast, value} ->
        [dbg_format_ast(to_string_with_colors(ast, options)), " ", inspect(value, options), ?\n]
      end)

    {formatted, final_value}
  end

  defp dbg_format_ast_to_debug({:block, components, value}, options) do
    formatted =
      [
        dbg_maybe_underline("Code block", options),
        ":\n(\n",
        Enum.map(components, fn {ast, value} ->
          ["  ", dbg_format_ast_with_value(ast, value, options)]
        end),
        ")\n"
      ]

    {formatted, value}
  end

  defp dbg_format_ast_to_debug({:case, ast, expr_value, clause_index, value}, options) do
    {:case, _meta, [expr_ast, _]} = ast

    formatted = [
      dbg_maybe_underline("Case argument", options),
      ":\n",
      dbg_format_ast_with_value(expr_ast, expr_value, options),
      ?\n,
      dbg_maybe_underline("Case expression", options),
      " (clause ##{clause_index + 1} matched):\n",
      dbg_format_ast_with_value(ast, value, options)
    ]

    {formatted, value}
  end

  defp dbg_format_ast_to_debug(
         {:cond, ast, clause_ast, clause_value, clause_index, value},
         options
       ) do
    formatted = [
      dbg_maybe_underline("Cond clause", options),
      " (clause ##{clause_index + 1} matched):\n",
      dbg_format_ast_with_value(clause_ast, clause_value, options),
      ?\n,
      dbg_maybe_underline("Cond expression", options),
      ":\n",
      dbg_format_ast_with_value(ast, value, options)
    ]

    {formatted, value}
  end

  defp dbg_format_ast_to_debug(
         {op, ast, condition_ast, condition_result, result},
         options
       )
       when op in [:if, :unless] do
    op_name = String.capitalize(Atom.to_string(op))

    formatted = [
      dbg_maybe_underline("#{op_name} condition", options),
      ":\n",
      dbg_format_ast_with_value(condition_ast, condition_result, options),
      ?\n,
      dbg_maybe_underline("#{op_name} expression", options),
      ":\n",
      dbg_format_ast_with_value(ast, result, options)
    ]

    {formatted, result}
  end

  defp dbg_format_ast_to_debug({:with, ast, clauses, value}, options) do
    formatted_clauses =
      Enum.map(clauses, fn {clause_ast, clause_value} ->
        dbg_format_ast_with_value(clause_ast, clause_value, options)
      end)

    formatted = [
      dbg_maybe_underline("With clauses", options),
      ":\n",
      formatted_clauses,
      ?\n,
      dbg_maybe_underline("With expression", options),
      ":\n",
      dbg_format_ast_with_value(ast, value, options)
    ]

    {formatted, value}
  end

  defp dbg_format_ast_to_debug({:value, code_ast, value}, options) do
    {dbg_format_ast_with_value(code_ast, value, options), value}
  end

  defp dbg_format_ast_with_value(ast, value, options) do
    [dbg_format_ast(to_string_with_colors(ast, options)), " ", inspect(value, options), ?\n]
  end

  defp to_string_with_colors(ast, options) do
    options = Keyword.take(options, [:syntax_colors])

    algebra = Code.quoted_to_algebra(ast, options)
    IO.iodata_to_binary(Inspect.Algebra.format(algebra, 98))
  end

  defp dbg_format_header(env) do
    env = Map.update!(env, :file, &(&1 && Path.relative_to_cwd(&1)))
    [stacktrace_entry] = Macro.Env.stacktrace(env)
    "[" <> Exception.format_stacktrace_entry(stacktrace_entry) <> "]"
  end

  defp dbg_maybe_underline(string, options) do
    if options[:syntax_colors] != [] do
      IO.ANSI.format([:underline, string, :reset])
    else
      string
    end
  end

  defp dbg_format_ast(ast) do
    [ast, :faint, " #=>", :reset]
  end
end
