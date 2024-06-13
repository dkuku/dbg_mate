defmodule DbgMate.InspectTest do
  use ExUnit.Case, async: true

  describe "dbg" do
    defmacrop dbg_format(ast, options) do
      quote do
        {result, formatted} =
          ExUnit.CaptureIO.with_io(fn ->
            unquote(DbgMate.Inspect.dbg(ast, options, __CALLER__))
          end)

        {result, formatted}
      end
    end

    test "test" do
      {result, formatted} =
        dbg_format(
          (
            a = 1
            b = 2 + 1
            a + b
          ),
          formatter: fn x -> x end
        )

      assert result == 4

      assert formatted == """
             20 | a = 1: 1
             21 | b = 2 + 1: 3
             """
    end

    test "stest 2" do
      Application.put_env(:elixir, :dbg_callback, {DbgMate.Inspect, :dbg, []})

      defmodule XXX do
        def function(_x) do
          a = 1
          b = 3
          d = a + b

          c =
            if a == 2 do
              2
            else
              b
            end

          j = fun(a, b)

          i =
            with e <- 1 + c,
                 f = b * e do
              f + e + j
            end

          z =
            for g <- a..d, h <- b..c do
              g + h + i
            end

          z
          |> Enum.map(&(&1 + 1))
          |> Enum.sum()
        end

        def fun(a, b) do
          c = a + b
          c
        end
      end
      |> dbg()

      {result, formatted} =
        ExUnit.CaptureIO.with_io(fn ->
          XXX.function(1)
        end)

      assert result == 106

      assert formatted == """
             40 | a = 1: 1
             41 | b = 3: 3
             42 | d = a + b: 4
             44 | c = if a == 2 do 2 else b end: 3
             70 | c = a + b: 4
             51 | j = fun(a, b): 4
             53 | i = with e <- 1 + c, f = b * e do f + e + j end: 20
             59 | z = for g <- a..d, h <- b..c do g + h + i end: [24, 25, 26, 27]
             66 | z |> Enum.map(&(&1 + 1)) |> Enum.sum(): 106
             """

      assert {3, "70 | c = a + b: 3\n"} ==
               ExUnit.CaptureIO.with_io(fn ->
                 XXX.fun(1, 2)
               end)
    end
  end
end
