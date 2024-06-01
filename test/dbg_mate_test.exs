defmodule CustomIf do
  def if(_cond, _expr) do
    "custom if result"
  end
end

defmodule DbgMateTest do
  use ExUnit.Case, async: true

  describe "dbg/3" do
    defmacrop dbg_format(ast, options \\ quote(do: [syntax_colors: []])) do
      quote do
        {result, formatted} =
          ExUnit.CaptureIO.with_io(fn ->
            unquote(DbgMate.dbg(ast, options, __CALLER__))
          end)

        # Make sure there's an empty line after the output.
        assert String.ends_with?(formatted, "\n\n") or
                 String.ends_with?(formatted, "\n\n" <> IO.ANSI.reset())

        {result, formatted}
      end
    end

    test "with a simple expression" do
      {result, formatted} = dbg_format(1 + 1)
      assert result == 2
      assert formatted =~ "1 + 1 #=> 2"
    end

    test "with variables" do
      my_var = 1 + 1
      {result, formatted} = dbg_format(my_var)
      assert result == 2
      assert formatted =~ "my_var #=> 2"
    end

    test "with a function call" do
      {result, formatted} = dbg_format(Atom.to_string(:foo))

      assert result == "foo"
      assert formatted =~ ~s[Atom.to_string(:foo) #=> "foo"]
    end

    test "with a multiline input" do
      {result, formatted} =
        dbg_format(
          case 1 + 1 do
            2 -> :two
            _other -> :math_is_broken
          end
        )

      assert result == :two

      assert formatted =~ """
             case 1 + 1 do
               2 -> :two
               _other -> :math_is_broken
             end #=> :two
             """
    end

    test "with a pipeline on a single line" do
      {result, formatted} = dbg_format([:a, :b, :c] |> tl() |> tl |> Kernel.hd())
      assert result == :c

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             \n[:a, :b, :c] #=> [:a, :b, :c]
             |> tl() #=> [:b, :c]
             |> tl #=> [:c]
             |> Kernel.hd() #=> :c
             """

      # Regression for pipes sometimes erroneously ending with three newlines (one
      # extra than needed).
      assert formatted =~ ~r/[^\n]\n\n$/
    end

    test "with a pipeline on multiple lines" do
      {result, formatted} =
        dbg_format(
          [:a, :b, :c]
          |> tl()
          |> tl
          |> Kernel.hd()
        )

      assert result == :c

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             \n[:a, :b, :c] #=> [:a, :b, :c]
             |> tl() #=> [:b, :c]
             |> tl #=> [:c]
             |> Kernel.hd() #=> :c
             """

      # Regression for pipes sometimes erroneously ending with three newlines (one
      # extra than needed).
      assert formatted =~ ~r/[^\n]\n\n$/
    end

    test "with simple boolean expressions" do
      {result, formatted} = dbg_format(:rand.uniform() < 0.0 and length([]) == 0)
      assert result == false

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             :rand.uniform() < 0.0 #=> false
             :rand.uniform() < 0.0 and length([]) == 0 #=> false
             """
    end

    test "with left-associative operators" do
      {result, formatted} = dbg_format(List.first([]) || "yes" || raise("foo"))
      assert result == "yes"

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             List.first([]) #=> nil
             List.first([]) || "yes" #=> "yes"
             List.first([]) || "yes" || raise "foo" #=> "yes"
             """
    end

    test "with composite boolean expressions" do
      true1 = length([]) == 0
      true2 = length([]) == 0
      {result, formatted} = dbg_format((true1 and true2) or (List.first([]) || true1))

      assert result == true

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             true1 #=> true
             true1 and true2 #=> true
             (true1 and true2) or (List.first([]) || true1) #=> true
             """
    end

    test "with block of code" do
      {result, formatted} =
        dbg_format(
          (
            a = 1
            b = a + 2
            a + b
          )
        )

      assert result == 4

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             Code block:
             (
               a = 1 #=> 1
               b = a + 2 #=> 3
               a + b #=> 4
             )
             """
    end

    test "with case" do
      list = [1, 2, 3]

      {result, formatted} =
        dbg_format(
          case list do
            [] -> nil
            _ -> Enum.sum(list)
          end
        )

      assert result == 6

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             Case argument:
             list #=> [1, 2, 3]

             Case expression (clause #2 matched):
             case list do
               [] -> nil
               _ -> Enum.sum(list)
             end #=> 6
             """
    end

    test "with case - guard" do
      {result, formatted} =
        dbg_format(
          case 0..100//5 do
            %{first: first, last: last, step: step} when last > first ->
              count = div(last - first, step)
              {:ok, count}

            _ ->
              :error
          end
        )

      assert result == {:ok, 20}

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             Case argument:
             0..100//5 #=> 0..100//5

             Case expression (clause #1 matched):
             case 0..100//5 do
               %{first: first, last: last, step: step} when last > first ->
                 count = div(last - first, step)
                 {:ok, count}

               _ ->
                 :error
             end #=> {:ok, 20}
             """
    end

    test "with cond" do
      map = %{b: 5}

      {result, formatted} =
        dbg_format(
          cond do
            a = map[:a] -> a + 1
            b = map[:b] -> b * 2
            true -> nil
          end
        )

      assert result == 10

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             Cond clause (clause #2 matched):
             b = map[:b] #=> 5

             Cond expression:
             cond do
               a = map[:a] -> a + 1
               b = map[:b] -> b * 2
               true -> nil
             end #=> 10
             """
    end

    test "if expression" do
      x = true
      map = %{a: 5, b: 1}

      Application.put_env(:elixir, :dbg_callback, {DbgMate, :dbg, []})

      {result, formatted} =
        dbg_format(
          if true and x do
            map[:a] * 2
          else
            map[:b]
          end
        )

      assert result == 10

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             If condition:
             true and x #=> true

             If expression:
             if true and x do
               map[:a] * 2
             else
               map[:b]
             end #=> 10
             """
    end

    test "if expression without else" do
      x = true
      map = %{a: 5, b: 1}

      {result, formatted} =
        dbg_format(
          if false and x do
            map[:a] * 2
          end
        )

      assert result == nil

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             If condition:
             false and x #=> false

             If expression:
             if false and x do
               map[:a] * 2
             end #=> nil
             """
    end

    test "custom if definition" do
      import Kernel, except: [if: 2]
      import CustomIf, only: [if: 2]

      {result, formatted} =
        dbg_format(
          if true do
            "something"
          end
        )

      assert result == "custom if result"

      assert formatted =~ """
             if true do
               "something"
             end #=> "custom if result"
             """
    end

    test "unless expression" do
      x = false
      map = %{a: 5, b: 1}

      {result, formatted} =
        dbg_format(
          unless true and x do
            map[:a] * 2
          else
            map[:b]
          end
        )

      assert result == 10

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             Unless condition:
             true and x #=> false

             Unless expression:
             unless true and x do
               map[:a] * 2
             else
               map[:b]
             end #=> 10
             """
    end

    test "with with/1 (all clauses match)" do
      opts = %{width: 10, height: 15}

      {result, formatted} =
        dbg_format(
          with {:ok, width} <- Map.fetch(opts, :width),
               double_width = width * 2,
               IO.puts("just a side effect"),
               {:ok, height} <- Map.fetch(opts, :height) do
            {:ok, double_width * height}
          end
        )

      assert result == {:ok, 300}

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             With clauses:
             Map.fetch(opts, :width) #=> {:ok, 10}
             width * 2 #=> 20
             Map.fetch(opts, :height) #=> {:ok, 15}

             With expression:
             with {:ok, width} <- Map.fetch(opts, :width),
                  double_width = width * 2,
                  IO.puts("just a side effect"),
                  {:ok, height} <- Map.fetch(opts, :height) do
               {:ok, double_width * height}
             end #=> {:ok, 300}
             """
    end

    test "with with/1 (no else)" do
      opts = %{width: 10}

      {result, formatted} =
        dbg_format(
          with {:ok, width} <- Map.fetch(opts, :width),
               {:ok, height} <- Map.fetch(opts, :height) do
            {:ok, width * height}
          end
        )

      assert result == :error

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             With clauses:
             Map.fetch(opts, :width) #=> {:ok, 10}
             Map.fetch(opts, :height) #=> :error

             With expression:
             with {:ok, width} <- Map.fetch(opts, :width),
                  {:ok, height} <- Map.fetch(opts, :height) do
               {:ok, width * height}
             end #=> :error
             """
    end

    test "with with/1 (else clause)" do
      opts = %{width: 10}

      {result, formatted} =
        dbg_format(
          with {:ok, width} <- Map.fetch(opts, :width),
               {:ok, height} <- Map.fetch(opts, :height) do
            width * height
          else
            :error -> 0
          end
        )

      assert result == 0

      assert formatted =~ "dbg_mate_test.exs"

      assert formatted =~ """
             With clauses:
             Map.fetch(opts, :width) #=> {:ok, 10}
             Map.fetch(opts, :height) #=> :error

             With expression:
             with {:ok, width} <- Map.fetch(opts, :width),
                  {:ok, height} <- Map.fetch(opts, :height) do
               width * height
             else
               :error -> 0
             end #=> 0
             """
    end

    test "with \"syntax_colors: []\" it doesn't print any color sequences" do
      {_result, formatted} = dbg_format("hello")
      refute formatted =~ "\e["
    end

    test "with \"syntax_colors: [...]\" it forces color sequences" do
      {_result, formatted} = dbg_format("hello", syntax_colors: [string: :cyan])
      assert formatted =~ IO.iodata_to_binary(IO.ANSI.format([:cyan, ~s("hello")]))
    end

    test "forwards options to the underlying inspect calls" do
      value = ~c"hello"
      assert {^value, formatted} = dbg_format(value, syntax_colors: [], charlists: :as_lists)
      assert formatted =~ "value #=> [104, 101, 108, 108, 111]\n"
    end

    test "with the :print_location option set to false, doesn't print any header" do
      {result, formatted} = dbg_format("hello", print_location: false)
      assert result == "hello"
      refute formatted =~ Path.basename(__ENV__.file)
    end
  end
end
