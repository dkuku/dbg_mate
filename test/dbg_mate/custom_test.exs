defmodule DbgMate.CustomTest do
  use ExUnit.Case, async: true

  describe "dbg" do
    defmacrop dbg_format(ast, options) do
      quote do
        {result, formatted} =
          ExUnit.CaptureIO.with_io(fn ->
            unquote(DbgMate.Custom.dbg(ast, options, __CALLER__))
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
          formatter: fn x -> x end,
          format: "$line | $code: $result\n"
        )

      assert result == 4

      assert formatted == """
              20 | a = 1: 1
              21 | b = 2 + 1: 3
             """
    end

    test "stest 2" do
      Application.put_env(:elixir, :dbg_callback, {DbgMate.Custom, :dbg, []})
      Application.put_env(:dbg_mate, :format, "$line | $code: $result\n")

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
      |> dbg(format: "$line | $code: $result\n")

      {result, formatted} =
        ExUnit.CaptureIO.with_io(fn ->
          XXX.function(1)
        end)

      assert result == 106

      assert formatted == """
             42 | a = 1: 1
             43 | b = 3: 3
             44 | d = a + b: 4
             46 | c = if a == 2 do 2 else b end: 3
             72 | c = a + b: 4
             53 | j = fun(a, b): 4
             55 | i = with e <- 1 + c, f = b * e do f + e + j end: 20
             61 | z = for g <- a..d, h <- b..c do g + h + i end: [24, 25, 26, 27]
             68 | z |> Enum.map(&(&1 + 1)) |> Enum.sum(): 106
             """

      assert {3, "72 | c = a + b: 3\n"} ==
               ExUnit.CaptureIO.with_io(fn ->
                 XXX.fun(1, 2)
               end)
    end
  end
end
